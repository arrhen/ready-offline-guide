import Foundation
import Testing
@testable import ReadyCore

@Suite struct ChatFormatTests {
    @Test func promptUsesChatMLWithThinkingOff() {
        let prompt = ChatFormat.prompt(for: [
            ChatMessage(role: .user, content: "How do I purify water?"),
        ])
        #expect(prompt.hasPrefix("<|im_start|>system\n"))
        #expect(prompt.contains("<|im_start|>user\nHow do I purify water?<|im_end|>\n"))
        #expect(prompt.hasSuffix("<|im_start|>assistant\n<think>\n\n</think>\n\n"))
    }

    @Test func promptKeepsTurnOrderAndSkipsEmptyMessages() {
        let prompt = ChatFormat.prompt(for: [
            ChatMessage(role: .user, content: "one"),
            ChatMessage(role: .assistant, content: "two"),
            ChatMessage(role: .user, content: "three"),
            ChatMessage(role: .assistant, content: ""),
        ])
        let one = prompt.range(of: "one")!, two = prompt.range(of: "two")!, three = prompt.range(of: "three")!
        #expect(one.lowerBound < two.lowerBound && two.lowerBound < three.lowerBound)
        #expect(prompt.components(separatedBy: "<|im_start|>assistant").count == 3)
    }

    @Test func excerptsGoIntoTheUserTurnAndTheSystemPromptSaysToStayWithinThem() {
        let prompt = ChatFormat.prompt(for: [
            ChatMessage(role: .user, content: "How long do I boil water?", context: "[1] Water - Boiling\nBoil for one minute."),
        ])
        #expect(prompt.contains("Guide excerpts:\n[1] Water - Boiling\nBoil for one minute.\n\nQuestion: How long do I boil water?"))
        #expect(ChatFormat.systemPrompt.contains("ONLY those excerpts"))
        #expect(ChatFormat.systemPrompt.contains("exactly as written"))
    }

    @Test func onlyTheLatestQuestionCarriesExcerpts() {
        let prompt = ChatFormat.prompt(for: [
            ChatMessage(role: .user, content: "first", context: "OLD EXCERPT"),
            ChatMessage(role: .assistant, content: "answer"),
            ChatMessage(role: .user, content: "second", context: "NEW EXCERPT"),
        ])
        #expect(!prompt.contains("OLD EXCERPT"))
        #expect(prompt.contains("NEW EXCERPT"))
        #expect(prompt.contains("<|im_start|>user\nfirst<|im_end|>"))
    }

    @Test func utf8SplitHoldsBackIncompleteCharacter() {
        // "é" is C3 A9; feed the first byte alone, then the rest.
        var bytes = Data("ok".utf8) + Data([0xC3])
        #expect(ChatFormat.takeValidUTF8(from: &bytes) == "ok")
        #expect(bytes == Data([0xC3]))
        bytes.append(0xA9)
        #expect(ChatFormat.takeValidUTF8(from: &bytes) == "é")
        #expect(bytes.isEmpty)
    }

    @Test func utf8SplitGivesUpOnGarbage() {
        var bytes = Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(!ChatFormat.takeValidUTF8(from: &bytes).isEmpty)
        #expect(bytes.isEmpty)
    }
}
