import Foundation

/// Everything found for a question, from the guides and from files the person added.
public struct Findings: Equatable, Sendable {
    /// True if the emergency screen caught the question. Nothing is searched in that case.
    public var isEmergency: Bool
    public var guides: [Passage]
    public var yours: [UserPassage]

    public var isEmpty: Bool { guides.isEmpty && yours.isEmpty }

    public static let emergency = Findings(isEmergency: true, guides: [], yours: [])
}

public enum Lookup {
    /// The emergency screen runs first, for both sources: an emergency-type question never shows
    /// passages that merely share words with it, whether they come from a guide or from a file.
    public static func run(_ question: String, pack: GuidePack?, library: UserLibrary?) -> Findings {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if SafetyScreen.triggers(trimmed) { return .emergency }
        return Findings(isEmergency: false,
                        guides: pack?.search(trimmed) ?? [],
                        yours: library?.search(trimmed) ?? [])
    }
}
