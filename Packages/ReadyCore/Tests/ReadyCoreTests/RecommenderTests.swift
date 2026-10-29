import Testing
@testable import ReadyCore

private let gb: UInt64 = 1_000_000_000

private func device(ram: UInt64, freeGB: Int64 = 60, lowPower: Bool = false,
                    thermal: ThermalLevel = .nominal) -> DeviceProfile {
    DeviceProfile(physicalMemoryBytes: ram, freeStorageBytes: freeGB * 1_000_000_000,
                  isLowPowerMode: lowPower, thermal: thermal)
}

@Suite struct RecommenderTests {
    @Test func ramClassCutoffs() {
        #expect(RAMClass(physicalMemoryBytes: 3_800_000_000) == .gb4)
        #expect(RAMClass(physicalMemoryBytes: 5_600_000_000) == .gb6)
        #expect(RAMClass(physicalMemoryBytes: 7_500_000_000) == .gb8Plus)
        #expect(RAMClass(physicalMemoryBytes: 11_000_000_000) == .gb8Plus)
    }

    @Test func fourGBGetsTinyOnly() {
        let r = Recommender.recommend(for: device(ram: 3_800_000_000))
        #expect(r.primary?.tier == .tiny)
        #expect(r.alternatives.isEmpty)
        #expect(r.settings.preset == .batterySaver)
        #expect(r.settings.contextLength == 2048)
    }

    @Test func sixGBGetsBalancedWithTinyAlternative() {
        let r = Recommender.recommend(for: device(ram: 5_600_000_000))
        #expect(r.primary?.tier == .balanced)
        #expect(r.alternatives.map(\.tier) == [.tiny])
        #expect(r.settings.contextLength == 4096)
    }

    @Test func eightGBGetsBestWithTwoAlternatives() {
        let r = Recommender.recommend(for: device(ram: 7_500_000_000))
        #expect(r.primary?.tier == .best)
        #expect(r.alternatives.map(\.tier) == [.balanced, .tiny])
        #expect(r.settings.preset == .balanced)
    }

    @Test func lowStorageFallsBackToSmallerModel() {
        // Best needs 2.5 GB + 2 GB headroom; 4 GB free rules it out, balanced (1.1 + 2) fits.
        let r = Recommender.recommend(for: device(ram: 7_500_000_000, freeGB: 4))
        #expect(r.primary?.tier == .balanced)
        #expect(!r.notes.isEmpty)
    }

    @Test func noStorageMeansLibraryOnly() {
        let r = Recommender.recommend(for: device(ram: 7_500_000_000, freeGB: 1))
        #expect(r.primary == nil)
        #expect(r.alternatives.isEmpty)
    }

    @Test func presetContextIsCappedByMemoryClass() {
        let s = Recommender.settings(for: .bestQuality, ramClass: .gb6)
        #expect(s.contextLength == 4096)
        #expect(Recommender.settings(for: .bestQuality, ramClass: .gb8Plus).contextLength == 8192)
    }

    @Test func lowPowerAndHeatDropPreset() {
        #expect(Recommender.effectivePreset(base: .bestQuality, device: device(ram: 8 * gb, lowPower: true)) == .batterySaver)
        #expect(Recommender.effectivePreset(base: .bestQuality, device: device(ram: 8 * gb, thermal: .serious)) == .batterySaver)
        #expect(Recommender.effectivePreset(base: .bestQuality, device: device(ram: 8 * gb, thermal: .fair)) == .balanced)
        #expect(Recommender.effectivePreset(base: .batterySaver, device: device(ram: 8 * gb, thermal: .fair)) == .batterySaver)
        #expect(Recommender.effectivePreset(base: .bestQuality, device: device(ram: 8 * gb)) == .bestQuality)
    }
}
