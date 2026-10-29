import Foundation
import Testing
@testable import ReadyCore

/// Runs a real model. Skipped unless READY_TEST_MODEL points at a Qwen3 GGUF file:
///   READY_TEST_MODEL=/path/to/Qwen3-0.6B-Q4_K_M.gguf swift test
private let modelPath = ProcessInfo.processInfo.environment["READY_TEST_MODEL"]

@Suite(.enabled(if: modelPath != nil)) struct LlamaEngineTests {
    private func engine() async throws -> LlamaEngine {
        try await LlamaEngine.load(modelURL: URL(fileURLWithPath: modelPath!), contextLength: 2048, useGPU: false)
    }

    private func reply(_ engine: LlamaEngine, _ messages: [ChatMessage], maxTokens: Int = 64) async throws -> String {
        var text = ""
        for try await piece in engine.generate(messages: messages, maxTokens: maxTokens) { text += piece }
        return text
    }

    @Test func answersAQuestion() async throws {
        let engine = try await engine()
        let text = try await reply(engine, [ChatMessage(role: .user, content: "Name one way to make river water safer to drink.")])
        print("REPLY:", text)
        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!text.contains("<think>"))
    }

    /// Prints how the model answers a medical question under the safety prompt. Not an assertion
    /// on content: a 0.6B model may ignore the prompt, which is why it is not a safety control.
    @Test func printsMedicalQuestionReply() async throws {
        let engine = try await engine()
        for question in ["How do I treat a minor burn?", "What dose of ibuprofen should I take for a fever?"] {
            let text = try await reply(engine, [ChatMessage(role: .user, content: question)], maxTokens: 160)
            print("Q:", question, "\nA:", text, "\n")
            #expect(!text.isEmpty)
        }
    }

    @Test func secondTurnWorksAfterFirst() async throws {
        let engine = try await engine()
        let first = try await reply(engine, [ChatMessage(role: .user, content: "Say hello in one word.")], maxTokens: 16)
        let second = try await reply(engine, [
            ChatMessage(role: .user, content: "Say hello in one word."),
            ChatMessage(role: .assistant, content: first),
            ChatMessage(role: .user, content: "Now say goodbye in one word."),
        ], maxTokens: 16)
        #expect(!second.isEmpty)
    }

    @Test func respectsTokenLimit() async throws {
        let engine = try await engine()
        let text = try await reply(engine, [ChatMessage(role: .user, content: "Write a long story about a river.")], maxTokens: 8)
        #expect(text.count < 200)
    }

    @Test func cancellationStopsGeneration() async throws {
        let engine = try await engine()
        let task = Task { () -> Int in
            var pieces = 0
            for try await _ in engine.generate(messages: [ChatMessage(role: .user, content: "Write a very long story.")], maxTokens: 1500) {
                pieces += 1
                if pieces == 5 { break }
            }
            return pieces
        }
        #expect(try await task.value == 5)
    }

    @Test func promptTooLongIsReported() async throws {
        let engine = try await engine()
        let huge = String(repeating: "water ", count: 4000)
        await #expect(throws: EngineError.self) {
            _ = try await reply(engine, [ChatMessage(role: .user, content: huge)])
        }
    }
}

/// A failed answer must leave the chat usable (it once stayed stuck until the screen was left).
@Suite(.enabled(if: modelPath != nil)) @MainActor struct ChatSessionTests {
    private func session() async throws -> ChatSession {
        let model = ModelCatalog.option(for: .tiny)
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ModelStore(directory: dir)
        try store.prepare()
        try FileManager.default.createSymbolicLink(at: store.fileURL(for: model),
                                                   withDestinationURL: URL(fileURLWithPath: modelPath!))
        let session = ChatSession()
        await session.load(model: model, store: store,
                           settings: Recommender.settings(for: .batterySaver, ramClass: .gb4), useGPU: false)
        return session
    }

    private func finish(_ session: ChatSession) async throws {
        for _ in 0..<600 where session.status == .generating { try await Task.sleep(for: .milliseconds(100)) }
    }

    @Test func failedAnswerLeavesChatReadyAndNextSendWorks() async throws {
        let session = try await session()
        #expect(session.status == .ready)

        session.send(String(repeating: "water ", count: 4000))
        try await finish(session)
        #expect(session.status == .ready)
        #expect(session.answerError != nil)

        session.send("Say hi in one word.")
        #expect(session.answerError == nil)
        try await finish(session)
        #expect(session.status == .ready)
        #expect(session.messages.last?.role == .assistant)
        #expect(session.messages.last?.content.isEmpty == false)
    }

    @Test func unloadWhileLoadingDropsTheEngine() async throws {
        let model = ModelCatalog.option(for: .tiny)
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = ModelStore(directory: dir)
        try store.prepare()
        try FileManager.default.createSymbolicLink(at: store.fileURL(for: model),
                                                   withDestinationURL: URL(fileURLWithPath: modelPath!))
        let session = ChatSession()
        let settings = Recommender.settings(for: .batterySaver, ramClass: .gb4)
        async let loading: Void = session.load(model: model, store: store, settings: settings, useGPU: false)
        try await Task.sleep(for: .milliseconds(50))
        session.unload()
        await loading
        #expect(session.status == .idle)
    }
}
