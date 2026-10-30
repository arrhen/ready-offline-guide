import Foundation

public enum Tier: Int, CaseIterable, Comparable, Sendable {
    case tiny, balanced, best

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    public var label: String {
        switch self {
        case .tiny: "Tiny"
        case .balanced: "Balanced"
        case .best: "Best"
        }
    }

    init?(name: String) {
        switch name {
        case "tiny": self = .tiny
        case "balanced": self = .balanced
        case "best": self = .best
        default: return nil
        }
    }
}

public struct ModelOption: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var tier: Tier
    /// Exact file size; also used to confirm a download is complete.
    public var downloadBytes: Int64
    /// Approximate memory in use while answering (weights plus working memory).
    public var runtimeBytes: Int64
    public var license: String
    /// Hugging Face repository the file comes from, shown for attribution.
    public var source: String
    /// Pinned to a commit, so the file can't change underneath the checksum.
    public var downloadURL: URL
    public var sha256: String

    public init(id: String, name: String, tier: Tier, downloadBytes: Int64, runtimeBytes: Int64,
                license: String, source: String, downloadURL: URL, sha256: String) {
        self.id = id
        self.name = name
        self.tier = tier
        self.downloadBytes = downloadBytes
        self.runtimeBytes = runtimeBytes
        self.license = license
        self.source = source
        self.downloadURL = downloadURL
        self.sha256 = sha256
    }
}

public enum ModelCatalog {
    private struct Entry: Decodable {
        var id: String
        var name: String
        var tier: String
        var license: String
        var source: String
        var url: URL
        var sha256: String
        var downloadBytes: Int64
        var runtimeBytes: Int64
    }

    /// Loaded from `models.json`. A malformed catalog is a packaging bug, caught by tests.
    public static let all: [ModelOption] = {
        let url = Bundle.module.url(forResource: "models", withExtension: "json")!
        let entries = try! JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
        return entries.map {
            ModelOption(id: $0.id, name: $0.name, tier: Tier(name: $0.tier)!,
                        downloadBytes: $0.downloadBytes, runtimeBytes: $0.runtimeBytes,
                        license: $0.license, source: $0.source, downloadURL: $0.url, sha256: $0.sha256)
        }
    }()

    /// Models may only be fetched over HTTPS from these hosts, exactly. A file from anywhere else is
    /// never downloaded, whatever the catalog says.
    static let allowedHosts: Set<String> = ["huggingface.co"]

    public static func isAllowedSource(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.port == nil,
              let host = url.host?.lowercased() else { return false }
        return allowedHosts.contains(host)
    }

    public static func option(for tier: Tier) -> ModelOption {
        all.first { $0.tier == tier }!
    }
}
