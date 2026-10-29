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
}

public struct ModelOption: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var tier: Tier
    /// Approximate download size. Placeholder until models are benchmarked and pinned.
    public var downloadBytes: Int64
    /// Approximate memory in use while answering (weights plus working memory).
    public var runtimeBytes: Int64
    public var license: String

    public init(id: String, name: String, tier: Tier, downloadBytes: Int64,
                runtimeBytes: Int64, license: String) {
        self.id = id
        self.name = name
        self.tier = tier
        self.downloadBytes = downloadBytes
        self.runtimeBytes = runtimeBytes
        self.license = license
    }
}

public enum ModelCatalog {
    private static let gb: Int64 = 1_000_000_000

    /// Draft shortlist. Sizes are estimates for 4-bit GGUF builds; URLs and SHA-256 hashes
    /// get added in `models.json` when the download manager lands.
    public static let all: [ModelOption] = [
        ModelOption(id: "qwen3-0.6b-q4", name: "Qwen3 0.6B", tier: .tiny,
                    downloadBytes: gb / 2, runtimeBytes: gb * 7 / 10, license: "Apache 2.0"),
        ModelOption(id: "qwen3-1.7b-q4", name: "Qwen3 1.7B", tier: .balanced,
                    downloadBytes: gb * 11 / 10, runtimeBytes: gb * 3 / 2, license: "Apache 2.0"),
        ModelOption(id: "qwen3-4b-q4", name: "Qwen3 4B", tier: .best,
                    downloadBytes: gb * 5 / 2, runtimeBytes: gb * 33 / 10, license: "Apache 2.0"),
    ]

    public static func option(for tier: Tier) -> ModelOption {
        all.first { $0.tier == tier }!
    }
}
