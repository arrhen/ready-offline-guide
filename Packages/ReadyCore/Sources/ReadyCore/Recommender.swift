import Foundation

public enum Preset: Int, CaseIterable, Comparable, Sendable {
    case batterySaver, balanced, bestQuality

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    public var label: String {
        switch self {
        case .batterySaver: "Battery saver"
        case .balanced: "Balanced"
        case .bestQuality: "Best quality"
        }
    }

    var contextLength: Int {
        switch self {
        case .batterySaver: 2048
        case .balanced: 4096
        case .bestQuality: 8192
        }
    }

    var maxAnswerTokens: Int {
        switch self {
        case .batterySaver: 200
        case .balanced: 350
        case .bestQuality: 500
        }
    }
}

public struct Settings: Equatable, Sendable {
    public var preset: Preset
    public var contextLength: Int
    public var maxAnswerTokens: Int
}

public struct Recommendation: Equatable, Sendable {
    /// nil means no model fits: the Library still works on its own.
    public var primary: ModelOption?
    public var alternatives: [ModelOption]
    public var settings: Settings
    public var notes: [String]
}

/// Device-to-model rules. This table is the one place to tune as models change.
public enum Recommender {
    /// Models and settings offered per memory class.
    struct Rule {
        var offered: [Tier]
        var defaultTier: Tier
        var defaultPreset: Preset
        var maxContext: Int
    }

    static let rules: [RAMClass: Rule] = [
        .gb4: Rule(offered: [.tiny], defaultTier: .tiny, defaultPreset: .batterySaver, maxContext: 2048),
        .gb6: Rule(offered: [.tiny, .balanced], defaultTier: .balanced, defaultPreset: .balanced, maxContext: 4096),
        .gb8Plus: Rule(offered: [.tiny, .balanced, .best], defaultTier: .best, defaultPreset: .balanced, maxContext: 8192),
    ]

    /// Model plus working memory must stay under this share of RAM, or iOS may end the app.
    static let memoryShare = 0.55
    /// Free space to keep after the download.
    static let storageHeadroom: Int64 = 2_000_000_000

    public static func recommend(for device: DeviceProfile, catalog: [ModelOption] = ModelCatalog.all) -> Recommendation {
        let ramClass = RAMClass(physicalMemoryBytes: device.physicalMemoryBytes)
        let rule = rules[ramClass]!
        let memoryBudget = Double(device.physicalMemoryBytes) * memoryShare

        var notes: [String] = []
        let byRAM = catalog.filter { rule.offered.contains($0.tier) && Double($0.runtimeBytes) <= memoryBudget }
        let fitting = byRAM.filter { $0.downloadBytes + storageHeadroom <= device.freeStorageBytes }
        if fitting.count < byRAM.count {
            notes.append("Some larger models are hidden because they would leave less than 2 GB free.")
        }

        let preferred = fitting.first { $0.tier == rule.defaultTier }
        let primary = preferred ?? fitting.max { $0.tier < $1.tier }
        if let primary, preferred == nil, primary.tier != rule.defaultTier {
            notes.append("A smaller model is recommended to fit your free space.")
        }
        if primary == nil {
            notes.append("Not enough free space for a model. The Library works without one.")
        }

        let alternatives = fitting.filter { $0.id != primary?.id }.sorted { $0.tier > $1.tier }
        let settings = settings(for: rule.defaultPreset, ramClass: ramClass)
        return Recommendation(primary: primary, alternatives: alternatives, settings: settings, notes: notes)
    }

    /// Settings for a preset, capped to what the memory class can handle.
    public static func settings(for preset: Preset, ramClass: RAMClass) -> Settings {
        let cap = rules[ramClass]!.maxContext
        return Settings(preset: preset, contextLength: min(preset.contextLength, cap),
                        maxAnswerTokens: preset.maxAnswerTokens)
    }

    /// Drops to a lighter preset while the phone is low on power or running hot.
    public static func effectivePreset(base: Preset, device: DeviceProfile) -> Preset {
        if device.isLowPowerMode || device.thermal >= .serious { return .batterySaver }
        if device.thermal == .fair { return min(base, .balanced) }
        return base
    }
}
