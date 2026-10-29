import Testing
@testable import ReadyCore

@Suite struct AppearanceTests {
    @Test func systemFollowsDeviceWhenKnown() {
        #expect(AppearanceChoice.system.resolved(systemKnown: true) == .followSystem)
    }

    @Test func systemFallsBackToDarkWhenUnknown() {
        #expect(AppearanceChoice.system.resolved(systemKnown: false) == .dark)
    }

    @Test func explicitChoiceWinsEitherWay() {
        for known in [true, false] {
            #expect(AppearanceChoice.light.resolved(systemKnown: known) == .light)
            #expect(AppearanceChoice.dark.resolved(systemKnown: known) == .dark)
        }
    }

    @Test func rawValuesAreStableForStorage() {
        #expect(AppearanceChoice(rawValue: "system") == .system)
        #expect(AppearanceChoice(rawValue: "nonsense") == nil)
    }
}
