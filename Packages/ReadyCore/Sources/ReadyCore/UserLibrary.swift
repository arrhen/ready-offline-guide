import Foundation
import SQLite3

public struct UserDocument: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let addedAt: Date
    public let passageCount: Int
    public let characterCount: Int
}

/// A passage found in a file the person added. It has no licence or review status: it is theirs.
public struct UserPassage: Identifiable, Equatable, Sendable {
    public let id: Int
    public let documentID: Int
    public let documentTitle: String
    public let heading: String
    public let body: String
    public let addedAt: Date
}

public enum UserLibraryError: Error { case cannotOpen, writeFailed }

/// Text from files the person added, stored on this phone and searched with the guides. Only the
/// extracted text is kept: no original file is copied, so there is nothing to re-open, share or export.
/// Nothing here touches the network, and the library is never uploaded, shared or exported.
public final class UserLibrary: @unchecked Sendable {
    public static let includeInBackupKey = "userLibraryIncludedInBackup"
    public static let maxDocuments = 500

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "UserLibrary", directoryHint: .isDirectory)
    }

    /// The library the app uses. Nil only if the database cannot be created.
    public static let shared: UserLibrary? = try? UserLibrary(directory: defaultDirectory)

    public let directory: URL
    private let defaults: UserDefaults
    private var db: OpaquePointer?
    private let lock = NSLock()

    public init(directory: URL, defaults: UserDefaults = .standard) throws {
        self.directory = directory
        self.defaults = defaults
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard sqlite3_open_v2(directory.appending(path: "library.sqlite").path, &db,
                              SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw UserLibraryError.cannotOpen
        }
        try runScript("""
            CREATE TABLE IF NOT EXISTS documents(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
              added REAL NOT NULL, passage_count INTEGER NOT NULL, characters INTEGER NOT NULL);
            CREATE VIRTUAL TABLE IF NOT EXISTS passages USING fts5(doc_id UNINDEXED, heading, body,
              tokenize='porter unicode61');
            PRAGMA user_version = 1;
            """)
        applyBackupPreference()
    }

    deinit { sqlite3_close(db) }

    // MARK: Backup

    /// Off unless the person turns it on. Files are kept out of iCloud and device backups by default.
    public var includedInBackup: Bool {
        get { defaults.bool(forKey: Self.includeInBackupKey) }
        set {
            defaults.set(newValue, forKey: Self.includeInBackupKey)
            applyBackupPreference()
        }
    }

    private func applyBackupPreference() {
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = !includedInBackup
        try? url.setResourceValues(values)
    }

    // MARK: Documents

    public func documents() -> [UserDocument] {
        locked {
            query("SELECT id, title, added, passage_count, characters FROM documents ORDER BY added DESC, id DESC", []) { row in
                UserDocument(id: Int(sqlite3_column_int64(row, 0)), title: Self.text(row, 1),
                             addedAt: Date(timeIntervalSince1970: sqlite3_column_double(row, 2)),
                             passageCount: Int(sqlite3_column_int64(row, 3)), characterCount: Int(sqlite3_column_int64(row, 4)))
            }
        }
    }

    @discardableResult
    public func add(_ document: ImportedDocument, at date: Date = Date()) throws -> UserDocument {
        try locked {
            let count = query("SELECT COUNT(*) FROM documents", []) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
            guard count < Self.maxDocuments else { throw ImportError.libraryFull }

            try runLocked("BEGIN")
            do {
                let characters = document.segments.reduce(0) { $0 + $1.text.count }
                try runLocked("INSERT INTO documents(title, added, passage_count, characters) VALUES (?1, ?2, ?3, ?4)",
                              [.text(document.title), .real(date.timeIntervalSince1970),
                               .int(document.segments.count), .int(characters)])
                let id = Int(sqlite3_last_insert_rowid(db))
                for segment in document.segments {
                    try runLocked("INSERT INTO passages(doc_id, heading, body) VALUES (?1, ?2, ?3)",
                                  [.int(id), .text(segment.heading), .text(segment.text)])
                }
                try runLocked("COMMIT")
                return UserDocument(id: id, title: document.title, addedAt: date,
                                    passageCount: document.segments.count, characterCount: characters)
            } catch {
                try? runLocked("ROLLBACK")
                throw error
            }
        }
    }

    public func remove(_ document: UserDocument) {
        locked {
            try? runLocked("DELETE FROM passages WHERE doc_id = ?1", [.int(document.id)])
            try? runLocked("DELETE FROM documents WHERE id = ?1", [.int(document.id)])
        }
    }

    public func removeAll() {
        locked {
            try? runLocked("DELETE FROM passages")
            try? runLocked("DELETE FROM documents")
            try? runLocked("VACUUM")
        }
    }

    // MARK: Search

    /// Passages that cover the question, best first. The same rules as the guides: nothing is returned
    /// unless enough of the question's words appear in the passage.
    public func search(_ question: String, limit: Int = 3) -> [UserPassage] {
        let terms = Retrieval.terms(from: question)
        guard !terms.isEmpty else { return [] }
        let match = terms.map { "\"\($0)\"" }.joined(separator: " OR ")
        let candidates: [UserPassage] = locked {
            query("""
                SELECT passages.rowid, passages.doc_id, d.title, passages.heading, passages.body, d.added
                FROM passages JOIN documents d ON d.id = passages.doc_id
                WHERE passages MATCH ?1 ORDER BY bm25(passages) LIMIT 20
                """, [.text(match)]) { row in
                UserPassage(id: Int(sqlite3_column_int64(row, 0)), documentID: Int(sqlite3_column_int64(row, 1)),
                            documentTitle: Self.text(row, 2), heading: Self.text(row, 3), body: Self.text(row, 4),
                            addedAt: Date(timeIntervalSince1970: sqlite3_column_double(row, 5)))
            }
        }
        return Array(candidates.filter { Retrieval.covers(terms: terms, in: $0.heading + " " + $0.body) }.prefix(limit))
    }

    // MARK: SQLite

    private enum Bind {
        case text(String), int(Int), real(Double)
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    /// For several statements at once (the schema). `runLocked` compiles only the first statement.
    private func runScript(_ sql: String) throws {
        try locked {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw UserLibraryError.writeFailed }
        }
    }

    private func runLocked(_ sql: String, _ binds: [Bind] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw UserLibraryError.writeFailed }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, binds)
        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else { throw UserLibraryError.writeFailed }
    }

    private func query<T>(_ sql: String, _ binds: [Bind], row: (OpaquePointer?) -> T) -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, binds)
        var rows: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW { rows.append(row(stmt)) }
        return rows
    }

    private func bind(_ stmt: OpaquePointer?, _ binds: [Bind]) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, value) in binds.enumerated() {
            let index = Int32(i + 1)
            switch value {
            case .text(let s): sqlite3_bind_text(stmt, index, s, -1, transient)
            case .int(let n): sqlite3_bind_int64(stmt, index, Int64(n))
            case .real(let d): sqlite3_bind_double(stmt, index, d)
            }
        }
    }

    private static func text(_ stmt: OpaquePointer?, _ column: Int32) -> String {
        sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
    }
}
