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

    public init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// Builds the prompt text. The Qwen3 models use ChatML, and an empty think block after the
/// assistant tag turns off their slow "thinking" mode so answers start straight away.
public enum ChatFormat {
    public static let systemPrompt = """
        You are Ready, an offline reference guide for practical situations: water, food safety, \
        shelter, fire, navigation, weather and power outages. Answer in short, plain steps. \
        If you are not sure, say so instead of guessing. Do not diagnose illnesses or injuries, \
        and do not give medication names or doses. For anything medical or life-threatening, say \
        to call the local emergency number first and to see a doctor.
        """

    public static func prompt(for messages: [ChatMessage]) -> String {
        var text = ""
        for message in [ChatMessage(role: .system, content: systemPrompt)] + messages where !message.content.isEmpty {
            text += "<|im_start|>\(message.role.tag)\n\(message.content)<|im_end|>\n"
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
