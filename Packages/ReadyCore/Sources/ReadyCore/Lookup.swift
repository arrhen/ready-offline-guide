import Foundation

/// Everything found for a question, from the guides and from files the person added.
public struct Findings: Equatable, Sendable {
    /// True if the emergency screen caught the question. Nothing is searched in that case.
    public var isEmergency: Bool
    public var guides: [Passage]
    public var yours: [UserPassage]
    /// True if the question names a child, a pet, a pregnancy or a mild symptom. Passages are shown
    /// with a warning and no model summary is written.
    public var needsCaution: Bool = false

    public var isEmpty: Bool { guides.isEmpty && yours.isEmpty }

    public static let emergency = Findings(isEmergency: true, guides: [], yours: [])
}

public enum Lookup {
    /// The emergency screen runs first, for both sources: an emergency-type question never shows
    /// passages that merely share words with it, whether they come from a guide or from a file.
    public static func run(_ question: String, pack: GuidePack?, library: UserLibrary?) -> Findings {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let level = SafetyScreen.level(trimmed)
        if level == .emergency { return .emergency }
        return Findings(isEmergency: false,
                        guides: pack?.search(trimmed) ?? [],
                        yours: library?.search(trimmed) ?? [],
                        needsCaution: level == .caution)
    }
}

extension Lookup {
    /// For a question the emergency screen stopped, after the person has explicitly asked and confirmed:
    /// text from files they added, and nothing else. No guide is searched and no model is involved, so
    /// Ready writes none of what is shown. The emergency screen is deliberately not applied here, because
    /// it already ran and the person chose to continue.
    public static func ownFilesOnly(_ question: String, library: UserLibrary?) -> [UserPassage] {
        library?.search(question.trimmingCharacters(in: .whitespacesAndNewlines)) ?? []
    }
}
