import Foundation
import SQLite3

public struct Guide: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let publisher: String
    public let sourceTitle: String
    public let sourceURL: URL
    public let sourceUpdated: String
    public let retrieved: String
    public let region: String
    public let licenseBasis: String
    public let isCleared: Bool
}

public struct GuideSection: Identifiable, Equatable, Sendable {
    public let id: Int
    public let guideID: String
    public let heading: String
    public let body: String
}

/// A passage found for a question, with where it came from.
public struct Passage: Identifiable, Equatable, Sendable {
    public var id: Int { section.id }
    public let section: GuideSection
    public let guide: Guide
}

public enum GuidePackError: Error { case cannotOpen, unsupportedFormat }

/// Read-only access to a guide pack (SQLite with an FTS5 index). See scripts/build-pack.py.
public final class GuidePack: @unchecked Sendable {
    public static let supportedFormat = 1

    private var db: OpaquePointer?
    /// Guides that are not cleared stay hidden unless this is true (Debug builds).
    private let includesUncleared: Bool

    public init(path: String, includesUncleared: Bool) throws {
        self.includesUncleared = includesUncleared
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw GuidePackError.cannotOpen
        }
        guard let version = try? scalarText("SELECT value FROM meta WHERE key = 'format_version'"),
              Int(version) == Self.supportedFormat else {
            sqlite3_close(db)
            throw GuidePackError.unsupportedFormat
        }
    }

    deinit { sqlite3_close(db) }

    static var bundledURL: URL? { Bundle.module.url(forResource: "core", withExtension: "sqlite") }

    /// The pack that ships inside the app.
    public static func bundled() -> GuidePack? {
        guard let url = bundledURL else { return nil }
        #if DEBUG
        let includesUncleared = true
        #else
        let includesUncleared = false
        #endif
        return try? GuidePack(path: url.path, includesUncleared: includesUncleared)
    }

    public func guides() -> [Guide] {
        query("SELECT id,title,publisher,source_title,source_url,source_updated,retrieved,region,license_basis,clearance FROM guides ORDER BY position", []) { Self.guide(from: $0) }
            .compactMap { $0 }
            .filter { includesUncleared || $0.isCleared }
    }

    public func sections(of guideID: String) -> [GuideSection] {
        guard guides().contains(where: { $0.id == guideID }) else { return [] }
        return query("SELECT id,guide_id,heading,body FROM sections WHERE guide_id = ? ORDER BY position", [guideID]) {
            GuideSection(id: Int(sqlite3_column_int64($0, 0)), guideID: Self.text($0, 1), heading: Self.text($0, 2), body: Self.text($0, 3))
        }
    }

    /// Passages that cover the question, best first. Returns nothing when no passage covers
    /// enough of what was asked, so the app can say it has no guide instead of guessing.
    public func search(_ question: String, limit: Int = 3) -> [Passage] {
        let terms = Retrieval.terms(from: question)
        guard !terms.isEmpty else { return [] }
        let match = terms.map { "\"\($0)\"" }.joined(separator: " OR ")
        let visible = Dictionary(uniqueKeysWithValues: guides().map { ($0.id, $0) })
        let candidates: [Passage] = query(
            "SELECT s.id, s.guide_id, s.heading, s.body FROM sections_fts f JOIN sections s ON s.id = f.rowid WHERE sections_fts MATCH ? ORDER BY bm25(sections_fts) LIMIT 20",
            [match]
        ) { row in
            let section = GuideSection(id: Int(sqlite3_column_int64(row, 0)), guideID: Self.text(row, 1),
                                       heading: Self.text(row, 2), body: Self.text(row, 3))
            guard let guide = visible[section.guideID] else { return nil as Passage? }
            return Passage(section: section, guide: guide)
        }.compactMap { $0 }
        return Array(candidates.filter { Retrieval.covers(terms: terms, in: $0.section.heading + " " + $0.section.body) }.prefix(limit))
    }

    // MARK: SQLite helpers

    private static func text(_ stmt: OpaquePointer?, _ column: Int32) -> String {
        sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
    }

    private static func guide(from row: OpaquePointer?) -> Guide? {
        guard let url = URL(string: text(row, 4)) else { return nil }
        return Guide(id: text(row, 0), title: text(row, 1), publisher: text(row, 2), sourceTitle: text(row, 3),
                     sourceURL: url, sourceUpdated: text(row, 5), retrieved: text(row, 6), region: text(row, 7),
                     licenseBasis: text(row, 8), isCleared: text(row, 9) == "cleared")
    }

    private func scalarText(_ sql: String) throws -> String? {
        query(sql, []) { Self.text($0, 0) }.first
    }

    private func query<T>(_ sql: String, _ args: [String], row: (OpaquePointer?) -> T) -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, arg) in args.enumerated() { sqlite3_bind_text(stmt, Int32(i + 1), arg, -1, transient) }
        var rows: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW { rows.append(row(stmt)) }
        return rows
    }
}

/// Turns a question into search terms and decides whether a passage really covers it.
public enum Retrieval {
    static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "if", "then", "so", "of", "to", "in", "on", "at", "by", "for",
        "with", "from", "as", "is", "are", "was", "were", "be", "been", "am", "do", "does", "did", "can",
        "could", "should", "would", "will", "shall", "may", "might", "i", "you", "he", "she", "it", "we",
        "they", "me", "my", "your", "our", "their", "this", "that", "these", "those", "what", "which", "who",
        "how", "when", "where", "why", "much", "many", "any", "some", "about", "into", "out", "up", "down",
        "get", "make", "need", "want", "please", "tell", "give", "show", "there", "have", "has", "had",
    ]

    /// Lowercase content words, de-duplicated, in order.
    public static func terms(from question: String) -> [String] {
        var seen = Set<String>()
        return question.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
            .filter { seen.insert($0).inserted }
    }

    /// A crude stem so "boiling", "boiled" and "boil" line up.
    static func stem(_ word: String) -> String {
        var w = word
        for suffix in ["ing", "ed", "es", "s"] where w.count > suffix.count + 2 && w.hasSuffix(suffix) {
            w.removeLast(suffix.count)
            break
        }
        return w
    }

    /// True if the passage contains enough of the question's terms (at least 60%, rounded up).
    public static func covers(terms: [String], in text: String) -> Bool {
        guard !terms.isEmpty else { return false }
        let words = Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map { stem(String($0)) })
        let matched = terms.filter { words.contains(stem($0)) }.count
        let needed = Int((Double(terms.count) * 0.6).rounded(.up))
        return matched >= needed
    }
}

/// A fixed check run before any search or model call. Questions that look like a medical
/// emergency, a poisoning or a request for symptoms or doses get a fixed reply, because word
/// overlap with a guide does not mean the guide can answer them safely.
public enum SafetyScreen {
    private static let phrases = [
        "chest pain", "heart attack", "not breathing", "can't breathe", "cant breathe", "cannot breathe",
        "passed out", "poison control", "carbon monoxide", "what do i do if", "what should i do if",
    ]

    private static let stems: Set<String> = [
        "poison", "poisoned", "poisoning", "swallow", "swallowed", "drank", "drunk", "ingest", "ingested",
        "overdose", "overdosed", "symptom", "unconscious", "unresponsive", "faint", "fainted", "bleed",
        "bleeding", "seizure", "convulsion", "allergic", "anaphylaxis", "suicid", "suicide", "choke",
        "choking", "stroke", "dose", "dosage", "dying", "died", "sick", "vomit", "vomiting", "diagnose",
        "diagnosis", "infection", "infected", "fever", "pregnant", "pregnancy", "baby", "infant", "toddler",
        "child", "children", "pet", "dog", "cat",
    ]

    public static func triggers(_ question: String) -> Bool {
        let lower = question.lowercased()
        if phrases.contains(where: { lower.contains($0) }) { return true }
        let words = lower.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
        return words.contains { stems.contains($0) || stems.contains(Retrieval.stem($0)) }
    }

    public static func reply(emergency: String) -> String {
        "This sounds like it could be a medical emergency, a poisoning, or something that needs a professional. Ready can't help with that. Call \(emergency) now, or your local poison control center. Don't wait for an answer here."
    }
}

/// What the app does with a question. The emergency screen always runs first, so an
/// emergency-type question never shows passages that merely share words with it.
public enum LookupResult: Equatable, Sendable {
    case emergency
    case passages([Passage])
    case noMatch
}

extension GuidePack {
    public func lookup(_ question: String) -> LookupResult {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if SafetyScreen.triggers(trimmed) { return .emergency }
        let found = search(trimmed)
        return found.isEmpty ? .noMatch : .passages(found)
    }
}
