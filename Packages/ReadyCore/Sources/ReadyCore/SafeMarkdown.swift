import Foundation

/// Turns model output into text for display. The model's words may be styled (bold, italics) but
/// never become links or images, so nothing it writes can send a person to a website or load
/// anything. Tapping a link in a model's answer is how a text-only model would reach the outside.
public enum SafeMarkdown {
    public static func render(_ text: String) -> AttributedString {
        if text.isEmpty { return AttributedString("…") }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard var result = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        // Collect first: changing attributes while walking the runs would invalidate the walk.
        let unsafe = result.runs.filter { $0.link != nil || $0.imageURL != nil }.map(\.range)
        for range in unsafe {
            result[range].link = nil
            result[range].imageURL = nil
        }
        return result
    }
}
