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

    /// The guides answers come from. Nil means nothing can be answered.
    @ObservationIgnored private let pack: GuidePack?

    public init(pack: GuidePack? = GuidePack.bundled()) {
        self.pack = pack
    }

    /// Shown instead of an answer when no guide covers the question. The model is not asked.
    public static func noGuideReply(emergency: String) -> String {
        "I don't have a guide that covers that, so I won't guess. Ready only answers from the guides it includes. Try different words, or browse the guides below. In an emergency, call \(emergency)."
    }

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
        let emergency = EmergencyNumber.phrase(forRegion: Locale.current.region?.identifier)
        let passages: [Passage]
        switch pack?.lookup(trimmed) ?? .noMatch {
        case .emergency:
            messages.append(ChatMessage(role: .user, content: trimmed))
            messages.append(ChatMessage(role: .assistant, content: SafetyScreen.reply(emergency: emergency)))
            answerError = nil
            return
        case .noMatch:
            messages.append(ChatMessage(role: .user, content: trimmed))
            messages.append(ChatMessage(role: .assistant, content: Self.noGuideReply(emergency: emergency)))
            answerError = nil
            return
        case .passages(let found):
            passages = found
        }
        let excerpts = passages.enumerated().map { i, p in
            "[\(i + 1)] \(p.guide.title) - \(p.section.heading)\n\(p.section.body)"
        }.joined(separator: "\n\n")
        messages.append(ChatMessage(role: .user, content: trimmed, context: excerpts))
        messages.append(ChatMessage(role: .assistant, content: "", sources: passages))
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
