import Foundation
import CryptoKit

public enum InstallError: LocalizedError, Equatable {
    case sizeMismatch, checksumMismatch

    public var errorDescription: String? {
        switch self {
        case .sizeMismatch: "The download was incomplete. Try again."
        case .checksumMismatch: "The file didn't match its checksum, so it was discarded. Try again."
        }
    }
}

/// Where downloaded models live, and how a finished download becomes an installed one.
public struct ModelStore: Sendable {
    public let directory: URL

    public init(directory: URL = ModelStore.defaultDirectory) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Models", directoryHint: .isDirectory)
    }

    public func fileURL(for model: ModelOption) -> URL {
        directory.appending(path: "\(model.id).gguf")
    }

    public func partialURL(forModelID id: String) -> URL {
        directory.appending(path: "\(id).part")
    }

    /// Creates the folder and keeps it out of iCloud backups: models can be downloaded again.
    public func prepare() throws {
        var dir = directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try dir.setResourceValues(values)
    }

    public func installedSize(of model: ModelOption) -> Int64? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL(for: model).path)
        return (attrs?[.size] as? NSNumber)?.int64Value
    }

    public func isInstalled(_ model: ModelOption) -> Bool {
        installedSize(of: model) == model.downloadBytes
    }

    public func delete(_ model: ModelOption) throws {
        for url in [fileURL(for: model), partialURL(forModelID: model.id)]
        where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Checks size and SHA-256, then moves the file into place. A bad file is deleted.
    public func install(downloaded: URL, model: ModelOption) throws {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: downloaded.path)
            guard (attrs[.size] as? NSNumber)?.int64Value == model.downloadBytes else {
                throw InstallError.sizeMismatch
            }
            guard try Self.sha256(of: downloaded) == model.sha256.lowercased() else {
                throw InstallError.checksumMismatch
            }
            let destination = fileURL(for: model)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: downloaded, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: downloaded)
            throw error
        }
    }

    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
