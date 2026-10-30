import Foundation

public enum ChatRole: Sendable {
    case system, user, assistant

    var tag: String {
        switch self {
        case .system: "system"
        case .user: "user"
        case .assistant: "assistant"
        }
    }
}

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var role: ChatRole
    public var content: String
    /// Guide excerpts the model is given with a question. Not shown as part of the message.
    public var context: String?
    /// The passages an answer was based on, shown under it.
    public var sources: [Passage]

    public init(id: UUID = UUID(), role: ChatRole, content: String, context: String? = nil, sources: [Passage] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.context = context
        self.sources = sources
    }
}

/// Builds the prompt text. The Qwen3 models use ChatML, and an empty think block after the
/// assistant tag turns off their slow "thinking" mode so answers start straight away.
public enum ChatFormat {
    public static let systemPrompt = """
        You are Ready, an offline reference guide. You are given excerpts from official guides. \
        Answer using ONLY those excerpts, in short, plain steps, keeping numbers, amounts and \
        times exactly as written. If the excerpts do not answer the question, say you don't know. \
        Do not diagnose illnesses or injuries and do not give medication names or doses. For \
        anything medical or life-threatening, say to call the local emergency number first.
        """

    public static func prompt(for messages: [ChatMessage]) -> String {
        var text = ""
        // Only the latest question carries excerpts, so the model sees the same passages the
        // person sees under the answer.
        let lastUser = messages.lastIndex { $0.role == .user }
        let all = [ChatMessage(role: .system, content: systemPrompt)] + messages
        for (i, message) in all.enumerated() where !message.content.isEmpty {
            let isLast = lastUser.map { $0 + 1 == i } ?? false
            let body = (isLast ? message.context : nil).map { "Guide excerpts:\n\($0)\n\nQuestion: \(message.content)" } ?? message.content
            text += "<|im_start|>\(message.role.tag)\n\(body)<|im_end|>\n"
        }
        return text + "<|im_start|>assistant\n<think>\n\n</think>\n\n"
    }

    /// Splits off the longest prefix that is valid UTF-8, leaving an incomplete trailing
    /// character in `bytes` for the next token to finish.
    static func takeValidUTF8(from bytes: inout Data) -> String {
        for cut in 0...min(3, bytes.count) {
            if let text = String(data: bytes.dropLast(cut), encoding: .utf8) {
                bytes = Data(bytes.suffix(cut))
                return text
            }
        }
        // Not valid even with a partial character left over: give up on those bytes.
        let text = String(decoding: bytes, as: UTF8.self)
        bytes.removeAll()
        return text
    }
}
