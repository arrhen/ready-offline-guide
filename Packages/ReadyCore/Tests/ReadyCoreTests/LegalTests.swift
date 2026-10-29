import Foundation
import Testing
@testable import ReadyCore

@Suite struct LegalTests {
    @Test func emergencyNumbersForKnownRegions() {
        #expect(EmergencyNumber.text(forRegion: "US") == "911")
        #expect(EmergencyNumber.text(forRegion: "gb") == "999")
        #expect(EmergencyNumber.text(forRegion: "AU") == "000")
        #expect(EmergencyNumber.text(forRegion: "NZ") == "111")
        #expect(EmergencyNumber.text(forRegion: "DE") == "112")
    }

    @Test func unknownRegionsNeverGuessANumber() {
        for region in [nil, "", "JP", "BR", "ZZ"] as [String?] {
            #expect(EmergencyNumber.text(forRegion: region) == "your local emergency number")
        }
    }

    @Test func knownNumbersAreAlwaysPairedWithTheLocalReminder() {
        #expect(EmergencyNumber.phrase(forRegion: "US") == "911 (or the local emergency number where you are)")
        #expect(EmergencyNumber.phrase(forRegion: "DE").contains("local emergency number where you are"))
        #expect(EmergencyNumber.phrase(forRegion: "JP") == "your local emergency number")
        #expect(EmergencyNumber.phrase(forRegion: nil) == "your local emergency number")
    }

    @Test func privacyTextDisclosesTheReportEmail() {
        let privacy = Legal.sections(emergency: "911").first { $0.title == "Privacy" }
        #expect(privacy?.body.contains("Report this answer") == true)
    }

    @Test func keyPointsCoverTheEssentials() {
        let text = Legal.keyPoints(emergency: "911").joined(separator: " ")
        #expect(text.contains("not a substitute for professional help"))
        #expect(text.contains("Check with a doctor"))
        #expect(text.contains("call 911 first"))
        #expect(text.contains("own risk"))
    }

    @Test func fullTextNamesTheEmergencyNumberAndNoWarranty() {
        let sections = Legal.sections(emergency: "112")
        #expect(sections.contains { $0.body.contains("112") })
        #expect(sections.contains { $0.title == "No warranty" && $0.body.contains("as is") })
        #expect(sections.contains { $0.body.contains(Legal.contactEmail) })
    }

    @Test func reportLinkIsAMailtoWithTheAnswer() throws {
        let url = try #require(Legal.reportURL(question: "How do I treat a burn?", answer: "Cool it."))
        #expect(url.scheme == "mailto")
        let text = url.absoluteString.removingPercentEncoding ?? ""
        #expect(text.contains(Legal.contactEmail))
        #expect(text.contains("Cool it."))
        #expect(text.contains("How do I treat a burn?"))
    }
}
