import Foundation

public enum ThermalLevel: Int, Comparable, Sendable {
    case nominal, fair, serious, critical

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// What the recommender needs to know about the phone. Plain values so rules are testable.
public struct DeviceProfile: Equatable, Sendable {
    public var physicalMemoryBytes: UInt64
    public var freeStorageBytes: Int64
    public var isLowPowerMode: Bool
    public var thermal: ThermalLevel

    public init(physicalMemoryBytes: UInt64, freeStorageBytes: Int64,
                isLowPowerMode: Bool = false, thermal: ThermalLevel = .nominal) {
        self.physicalMemoryBytes = physicalMemoryBytes
        self.freeStorageBytes = freeStorageBytes
        self.isLowPowerMode = isLowPowerMode
        self.thermal = thermal
    }

    /// Reads the current device.
    public static func current() -> DeviceProfile {
        let info = ProcessInfo.processInfo
        let free = (try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage) ?? 0
        let thermal: ThermalLevel
        switch info.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .fair
        }
        return DeviceProfile(physicalMemoryBytes: info.physicalMemory, freeStorageBytes: free,
                             isLowPowerMode: info.isLowPowerModeEnabled, thermal: thermal)
    }
}

/// Nominal memory class. `physicalMemory` reports slightly under the marketing number
/// (a "4 GB" phone is about 3.7 GB), so the cut-offs sit between classes.
public enum RAMClass: Int, Comparable, Sendable {
    case gb4 = 4, gb6 = 6, gb8Plus = 8

    public init(physicalMemoryBytes: UInt64) {
        switch physicalMemoryBytes {
        case ..<5_000_000_000: self = .gb4
        case ..<7_000_000_000: self = .gb6
        default: self = .gb8Plus
        }
    }

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}
