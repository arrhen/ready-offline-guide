import Foundation
import Observation

/// One conversation with a loaded model, for the chat screen.
@MainActor @Observable
public final class ChatSession {
    public enum Status: Equatable {
        case idle, loading, ready, generating
        case failed(String)
    }

    public private(set) var messages: [ChatMessage] = []
    public private(set) var status: Status = .idle
    /// Why the last answer failed. The chat stays usable; this clears on the next send.
    public private(set) var answerError: String?

    @ObservationIgnored private var engine: LlamaEngine?
    @ObservationIgnored private var generation: Task<Void, Never>?
    @ObservationIgnored private var maxAnswerTokens = 256
    /// False once `unload()` runs, so a load that finishes afterwards is dropped.
    @ObservationIgnored private var wantsLoaded = false

    public init() {}

    /// Loads the model. Does nothing if one is already loaded.
    public func load(model: ModelOption, store: ModelStore = ModelStore(), settings: Settings, useGPU: Bool) async {
        wantsLoaded = true
        guard engine == nil, status != .loading else { return }
        status = .loading
        maxAnswerTokens = settings.maxAnswerTokens
        do {
            let loaded = try await LlamaEngine.load(modelURL: store.fileURL(for: model),
                                                    contextLength: settings.contextLength, useGPU: useGPU)
            guard wantsLoaded else {
                status = .idle
                return
            }
            engine = loaded
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Frees the model's memory. Conversation text is kept.
    public func unload() {
        wantsLoaded = false
        stop()
        engine = nil
        if status != .loading { status = .idle }
    }

    public func clear() {
        stop()
        messages.removeAll()
        answerError = nil
    }

    public func stop() {
        generation?.cancel()
    }

    public func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let engine, status == .ready, !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: trimmed))
        messages.append(ChatMessage(role: .assistant, content: ""))
        status = .generating
        answerError = nil
        let history = Array(messages.dropLast())
        let limit = maxAnswerTokens
        generation = Task {
            do {
                for try await piece in engine.generate(messages: history, maxTokens: limit) {
                    messages[messages.count - 1].content += piece
                }
                if messages.last?.content.isEmpty == true { messages.removeLast() }
                // Not ready again if the model was unloaded while answering.
                if self.engine != nil { status = .ready }
            } catch {
                if messages.last?.content.isEmpty == true { messages.removeLast() }
                answerError = error.localizedDescription
                if self.engine != nil { status = .ready }
            }
        }
    }
}
