import Testing
@testable import ReadyCore

@Suite struct DonationsTests {
    @Test func externalLinkOnlyOnTheUSStorefront() {
        #expect(Donations.showsExternalLink(storefrontCountryCode: "USA"))
        #expect(Donations.showsExternalLink(storefrontCountryCode: "usa"))
    }

    @Test func noExternalLinkAnywhereElseOrWhenUnknown() {
        for code in [nil, "", "GBR", "CAN", "DEU", "US", "AUS"] as [String?] {
            #expect(!Donations.showsExternalLink(storefrontCountryCode: code))
        }
    }

    @Test func sponsorsLinkIsHTTPSGitHub() {
        #expect(Donations.sponsorsURL.scheme == "https")
        #expect(Donations.sponsorsURL.host == "github.com")
    }
}
