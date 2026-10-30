import Foundation

/// Emergency number text for a region. Only numbers that are well established are listed;
/// anywhere else the text says "your local emergency number" rather than guess.
public enum EmergencyNumber {
    private static let euEEA: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IS", "IE",
        "IT", "LV", "LI", "LT", "LU", "MT", "NL", "NO", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
    ]

    /// Wording for the UI. The region setting is not where the phone is (think travel), so a
    /// known number is always paired with a reminder to use the local one.
    public static func phrase(forRegion region: String?) -> String {
        let number = text(forRegion: region)
        return number == "your local emergency number"
            ? number
            : "\(number) (or the local emergency number where you are)"
    }

    public static func text(forRegion region: String?) -> String {
        switch region?.uppercased() {
        case "US", "CA", "MX": "911"
        case "GB": "999"
        case "AU": "000"
        case "NZ": "111"
        case let code? where euEEA.contains(code): "112"
        default: "your local emergency number"
        }
    }
}

/// The wording shown in the app. Bump `version` when the meaning changes, so people are asked
/// to read it again.
public enum Legal {
    /// Bump when the wording changes in meaning, so people are shown the notice again.
    public static let version = 3
    public static let contactEmail = "privacy@arrhen.me"

    /// What this build contains. The notices describe only what is actually in the build: a files-only
    /// release must not talk about a model, downloads or guides it does not have.
    public struct Features: Equatable, Sendable {
        public var hasModel: Bool
        public var hasGuides: Bool

        public init(hasModel: Bool, hasGuides: Bool) {
            self.hasModel = hasModel
            self.hasGuides = hasGuides
        }

        public static let filesOnly = Features(hasModel: false, hasGuides: false)
        public static let everything = Features(hasModel: true, hasGuides: true)
    }

    public static func keyPoints(emergency: String, features: Features = .everything) -> [String] {
        var points = ["Ready is a reference tool, not a substitute for professional help."]
        switch (features.hasGuides, features.hasModel) {
        case (true, true):
            points.append("Guides can be incomplete or out of date. Answers written by the on-device model can be wrong.")
        case (true, false):
            points.append("Guides can be incomplete or out of date.")
        case (false, true):
            points.append("Answers written by the on-device model can be wrong, and the files they draw on haven't been reviewed.")
        case (false, false):
            points.append("Ready shows text from files you add, exactly as written. It hasn't reviewed them, and they can be incomplete, out of date or wrong.")
        }
        points += [
            "Don't use Ready to diagnose or treat a medical condition. Check with a doctor before making medical decisions.",
            "In a life-threatening situation, call \(emergency) first.",
            "Files you add stay on this phone and are your responsibility. Add only what you have the right to use.",
            "You use Ready at your own risk.",
        ]
        return points
    }

    public struct Section: Sendable {
        public let title: String
        public let body: String
    }

    public static func sections(emergency: String, features: Features = .everything) -> [Section] {
        let what: String
        switch (features.hasGuides, features.hasModel) {
        case (false, false): what = "searches files you add, on your phone"
        case (true, false): what = "collects reference material and searches it, with files you add, on your phone"
        case (false, true): what = "searches files you add and runs a small language model on your phone"
        case (true, true): what = "collects reference material and runs a small language model on your phone"
        }
        var accuracy = features.hasGuides
            ? "Guides show their source and date, but they can be incomplete, out of date or not right for your country or situation. "
            : "Ready shows text from files you add exactly as written. It hasn't reviewed them, and they can be incomplete, out of date or wrong. "
        if features.hasModel {
            accuracy += "Answers written by the model are generated text. A small model can sound confident and still be wrong, so check anything that matters against the source text and with a professional."
        } else {
            accuracy += "Check anything that matters with a qualified professional."
        }

        var network = "The only network use is downloading models or guide packs when you ask it to."
        var report = "If you choose \"Report this answer\", Ready opens a draft email containing that question and answer. Nothing is sent unless you send it."
        if !features.hasModel {
            network = "This version makes no network requests of its own."
            report = "If you choose \"Report a problem\", Ready opens a draft email. Nothing is sent unless you send it."
        }
        let privacy = "Ready has no accounts and collects no data. Your files and searches stay on your phone. \(network) Files you add are never sent anywhere. \(report)"

        var sources = features.hasGuides
            ? "Any guides included in Ready come from public-domain and openly licensed sources, and say where they came from. "
            : ""
        sources += "Ready is not affiliated with or endorsed by any government agency or publisher. The app includes the open-source llama.cpp library (MIT licence)"
        sources += features.hasModel ? " and runs Qwen3 models (Apache 2.0)." : "."
        sources += " Full notices are in the project's THIRD_PARTY_NOTICES file."

        return [
            Section(title: "Not professional advice",
                    body: "Ready is free, open-source software that \(what). It is not medical, legal, safety or emergency advice, and it does not create any professional relationship. Always get help from a qualified person where you can, and call \(emergency) in an emergency."),
            Section(title: "Accuracy", body: accuracy),
            Section(title: "No warranty",
                    body: "Ready is provided \"as is\" under the MIT licence, without warranty of any kind. To the extent the law allows, the authors are not liable for any loss, injury or damage arising from using it."),
            Section(title: "Privacy", body: privacy),
            Section(title: "Files you add",
                    body: "You can add text, Markdown and PDF files so Ready can search them. Add only files you own or have permission to use. Ready keeps only the text it reads from them, on this phone. It never uploads, shares or exports your files, and it doesn't open locked or copy-protected files. They are not backed up to iCloud unless you turn that on in Settings. Ready hasn't reviewed anything you add, and answers drawn from your files are only as good as the files. You are responsible for what you add and how you use it."),
            Section(title: "Sources and licences", body: sources),
            Section(title: "Contact", body: "Questions or problems: \(contactEmail)."),
        ]
    }

    public static let importNoticeVersion = 1
    public static let importNotice = "Only add files you own or have permission to use. Ready keeps the text of what you add on this phone. It doesn't upload, share or back it up unless you choose, and it doesn't open locked files."

    public static let emergencyFilesButton = "Can't reach emergency services? Show text from my own files"
    public static let emergencyFilesConfirmTitle = "Show text from your files?"

    /// Shown before text from the person's own files is displayed for an emergency-type question.
    public static func emergencyFilesConfirmation(emergency: String) -> String {
        "Call \(emergency) first if you can. Ready is not advice. It hasn't reviewed your files, can't tell whether a passage is correct or applies to this situation, and writes none of what it shows. It will only show text from files you added, exactly as written."
    }

    public static let emergencyFilesBanner = "Text from your own files, shown as written. Ready hasn't reviewed it and can't tell if it applies here. If anyone is in danger, get professional help as soon as you can."

    /// A pre-filled email for reporting a bad answer. The person sees and sends it themselves.
    public static func reportURL(question: String?, answer: String) -> URL? {
        var body = "What's wrong with this answer?\n\n\n---\n"
        if let question, !question.isEmpty { body += "Question: \(question)\n" }
        body += "Answer: \(answer)\n"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Ready: problem with an answer"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
