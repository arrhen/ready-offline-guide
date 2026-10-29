import Foundation

/// The user's light/dark choice. System is the default.
public enum AppearanceChoice: String, CaseIterable, Sendable {
    case system, light, dark

    public var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public enum ResolvedAppearance: Equatable, Sendable {
    case followSystem, light, dark
}

extension AppearanceChoice {
    /// System follows the device. If the device's setting can't be read, fall back to dark.
    public func resolved(systemKnown: Bool) -> ResolvedAppearance {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: systemKnown ? .followSystem : .dark
        }
    }
}
