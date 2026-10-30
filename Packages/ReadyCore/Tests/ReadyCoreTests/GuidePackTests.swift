import Foundation
import Testing
@testable import ReadyCore

@Suite struct GuidePackTests {
    private func pack() throws -> GuidePack {
        let url = try #require(GuidePack.bundledURL)
        return try GuidePack(path: url.path, includesUncleared: true)
    }

    // MARK: retrieval rules

    @Test func termsDropFillerWordsAndDuplicates() {
        #expect(Retrieval.terms(from: "How do I make water safe to drink water?") == ["water", "safe", "drink"])
    }

    @Test func coverageNeedsMostTermsToMatch() {
        #expect(Retrieval.covers(terms: ["burn"], in: "Cool the water") == false)
        #expect(Retrieval.covers(terms: ["boil", "water"], in: "Boiling water kills germs") == true)
        // "treat a burn" must not match water guidance just because it says "treat the water".
        #expect(Retrieval.covers(terms: ["treat", "burn"], in: "Treat the water first") == false)
    }

    @Test func stemsLineUpCommonForms() {
        #expect(Retrieval.stem("boiling") == Retrieval.stem("boiled"))
        #expect(Retrieval.stem("drops") == Retrieval.stem("drop"))
    }

    // MARK: the bundled pack

    @Test func bundledPackLoadsWithProvenanceOnEveryGuide() throws {
        let guides = try pack().guides()
        #expect(guides.count >= 2)
        for g in guides {
            #expect(g.sourceURL.scheme == "https")
            #expect(!g.publisher.isEmpty && !g.licenseBasis.isEmpty && !g.sourceUpdated.isEmpty && !g.retrieved.isEmpty)
        }
    }

    @Test func unclearedGuidesAreHiddenWhenNotIncluded() throws {
        let url = try #require(GuidePack.bundledURL)
        let strict = try GuidePack(path: url.path, includesUncleared: false)
        // Nothing is cleared yet, so a release-style pack shows no guides and answers nothing.
        #expect(strict.guides().filter { !$0.isCleared }.isEmpty)
        #expect(strict.search("how do I disinfect water with bleach").isEmpty)
    }

    /// Guards against a transcription error in safety numbers.
    @Test func waterGuideKeepsTheSourceNumbers() throws {
        let sections = try pack().sections(of: "water-emergency")
        let text = sections.map(\.body).joined(separator: "\n")
        for fact in ["rolling boil for at least one minute", "three minutes", "5,000 feet",
                     "8 drops of 6% bleach", "6 drops of 8.25% bleach", "Double the amount",
                     "30 minutes", "another 15 minutes", "1-800-426-4791", "less than one year"] {
            #expect(text.contains(fact), "missing: \(fact)")
        }
    }

    @Test func powerGuideKeepsTheSourceNumbers() throws {
        let text = try pack().sections(of: "power-outage").map(\.body).joined(separator: "\n")
        for fact in ["20 feet", "40 degrees", "about four hours", "about 48 hours", "two hours"] {
            #expect(text.contains(fact), "missing: \(fact)")
        }
    }

    @Test func searchFindsTheRightGuide() throws {
        let p = try pack()
        let water = p.search("How do I purify water with bleach?")
        #expect(water.first?.guide.id == "water-emergency")
        let boil = p.search("how long should I boil water")
        #expect(boil.first?.section.heading == "Boiling water")
        let generator = p.search("where can I use a generator")
        #expect(generator.first?.guide.id == "power-outage")
    }

    // MARK: emergency screen

    @Test func emergencyQuestionsAreCaughtBeforeSearch() throws {
        let p = try pack()
        let questions = [
            "What are the symptoms of carbon monoxide poisoning?",
            "I drank water with bleach in it, what do I do?",
            "my kid swallowed bleach",
            "someone is not breathing",
            "chest pain",
            "what dose of bleach is safe to drink",
        ]
        for q in questions {
            #expect(SafetyScreen.triggers(q), "should trigger: \(q)")
        }
        // Search alone would have answered both of these, with passages that do not address them.
        // That is why the screen runs first.
        #expect(!p.search("What are the symptoms of carbon monoxide poisoning?").isEmpty)
        #expect(!p.search("I drank water with bleach in it, what do I do?").isEmpty)
    }

    // MARK: lookup (what home search and chat both use)

    @Test func lookupRunsTheEmergencyScreenBeforeSearch() throws {
        let p = try pack()
        // Without the screen these return bleach-dose passages, which is worse shown bare.
        #expect(p.lookup("I drank water with bleach in it, what do I do?") == .emergency)
        #expect(p.lookup("What are the symptoms of carbon monoxide poisoning?") == .emergency)
    }

    @Test func lookupFindsPassagesForOrdinaryQuestions() throws {
        guard case .passages(let found) = try pack().lookup("How long should I boil water?") else {
            Issue.record("expected passages"); return
        }
        #expect(found.first?.guide.id == "water-emergency")
    }

    @Test func lookupSaysNoMatchWhenNothingCoversIt() throws {
        #expect(try pack().lookup("How do I build a shelter?") == .noMatch)
        #expect(try pack().lookup("   ") == .noMatch)
    }

    @Test func ordinaryGuideQuestionsAreNotBlocked() {
        for q in ["How long should I boil water?", "How much bleach per gallon of water?",
                  "Where can I use a generator?", "How long does food stay cold in a freezer?"] {
            #expect(!SafetyScreen.triggers(q), "should not trigger: \(q)")
        }
    }

    @Test func emergencyReplyNamesTheNumberAndRefuses() {
        let reply = SafetyScreen.reply(emergency: "911 (or the local emergency number where you are)")
        #expect(reply.contains("911"))
        #expect(reply.contains("can't help"))
    }

    /// Known gap: "indoors" is not a word in the generator guidance, so the most important generator
    /// question gets "no guide". Refusing is the safe direction. Adding keywords per section
    /// (indoors, garage, inside) would let it answer, and is tracked in docs/CONTENT_SOURCES.md.
    @Test func generatorIndoorsQuestionIsCurrentlyRefused() throws {
        #expect(try pack().search("is it safe to run a generator indoors").isEmpty)
    }

    @Test func searchRefusesQuestionsTheGuidesDoNotCover() throws {
        let p = try pack()
        for q in ["How do I treat a burn?", "What dose of ibuprofen for a fever?", "How do I build a shelter?", "", "the a of"] {
            #expect(p.search(q).isEmpty, "should not answer: \(q)")
        }
    }
}
