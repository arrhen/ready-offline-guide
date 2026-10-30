import Foundation
import PDFKit

/// A passage-sized piece of an imported file, with a label to show for it ("Page 12", "Part 3").
public struct Segment: Equatable, Sendable {
    public let heading: String
    public let text: String
}

public enum ImportError: LocalizedError, Equatable {
    case unsupportedType, tooLarge, symbolicLink, locked, copyProtected, noText, unreadable, libraryFull

    public var errorDescription: String? {
        switch self {
        case .unsupportedType: "This kind of file isn't supported yet. Ready reads text, Markdown and PDF files."
        case .tooLarge: "This file is too large to add."
        case .symbolicLink: "This is a shortcut to another file, not a file. Add the file itself."
        case .locked: "This PDF is locked with a password. Ready doesn't open locked files."
        case .copyProtected: "This PDF is copy-protected. Ready doesn't work around protection."
        case .noText: "There is no readable text in this file. It may be a scan, and Ready can't read images."
        case .unreadable: "Ready couldn't read this file."
        case .libraryFull: "Your files are full. Remove some before adding more."
        }
    }
}

public struct ImportLimits: Sendable {
    public var maxBytes: Int
    public var maxPages: Int
    public var maxCharacters: Int

    public init(maxBytes: Int, maxPages: Int, maxCharacters: Int) {
        self.maxBytes = maxBytes
        self.maxPages = maxPages
        self.maxCharacters = maxCharacters
    }

    /// A 1,000-page book is about 3 million characters.
    public static let standard = ImportLimits(maxBytes: 100_000_000, maxPages: 3000, maxCharacters: 10_000_000)
}

public struct ImportedDocument: Equatable, Sendable {
    public let title: String
    public let segments: [Segment]
}

/// Reads text out of a file the person chose. Local files only: this never fetches anything, and it
/// declines files that are protected, since working around protection is not something Ready does.
///
/// Files are untrusted. Types are limited to ones read without unpacking archives, and size, page and
/// text caps apply. Call it off the main thread.
public enum FileImporter {
    public static let supportedExtensions: Set<String> = ["txt", "text", "md", "markdown", "pdf"]

    public static func read(_ url: URL, limits: ImportLimits = .standard) throws -> ImportedDocument {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { throw ImportError.unsupportedType }

        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
        if values?.isSymbolicLink == true { throw ImportError.symbolicLink }
        if values?.isRegularFile == false { throw ImportError.unreadable }
        if let size = values?.fileSize, size > limits.maxBytes { throw ImportError.tooLarge }

        let title = url.deletingPathExtension().lastPathComponent
        let segments = ext == "pdf" ? try readPDF(url, limits: limits) : try readText(url, limits: limits)
        guard !segments.isEmpty else { throw ImportError.noText }
        return ImportedDocument(title: title.isEmpty ? "Untitled" : title, segments: segments)
    }

    // MARK: Text

    private static func readText(_ url: URL, limits: ImportLimits) throws -> [Segment] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { throw ImportError.unreadable }
        guard let raw = decode(data) else { throw ImportError.unreadable }
        let text = clean(raw)
        guard text.count <= limits.maxCharacters else { throw ImportError.tooLarge }
        return Chunker.split(text, heading: { "Part \($0)" })
    }

    private static func decode(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if data.prefix(2) == Data([0xFF, 0xFE]) || data.prefix(2) == Data([0xFE, 0xFF]),
           let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        // Not text: a binary file with a text extension.
        if data.prefix(4096).contains(0) { return nil }
        return String(data: data, encoding: .isoLatin1)
    }

    // MARK: PDF

    private static func readPDF(_ url: URL, limits: ImportLimits) throws -> [Segment] {
        guard let document = PDFDocument(url: url) else { throw ImportError.unreadable }
        if document.isLocked { throw ImportError.locked }
        if document.isEncrypted && !document.allowsCopying { throw ImportError.copyProtected }
        guard document.pageCount <= limits.maxPages else { throw ImportError.tooLarge }

        var segments: [Segment] = []
        var characters = 0
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let raw = page.string else { continue }
            let text = clean(raw)
            characters += text.count
            guard characters <= limits.maxCharacters else { throw ImportError.tooLarge }
            segments += Chunker.split(text, heading: { $0 == 1 ? "Page \(index + 1)" : "Page \(index + 1), part \($0)" })
        }
        return segments
    }

    // MARK: Cleaning

    /// Drops control characters (including NUL), normalizes line endings and collapses long runs of blank lines.
    static func clean(_ raw: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            if scalar == "\n" || scalar == "\t" || scalar == "\r" || !CharacterSet.controlCharacters.contains(scalar) {
                scalars.append(scalar)
            }
        }
        var text = String(scalars).replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        while text.contains("\n\n\n") { text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Splits text into passage-sized pieces at line boundaries, hard-cutting only a line that is itself too long.
public enum Chunker {
    public static let targetSize = 1200

    public static func split(_ text: String, heading: (Int) -> String) -> [Segment] {
        var pieces: [String] = []
        var current = ""
        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { pieces.append(trimmed) }
            current = ""
        }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var rest = Substring(line)
            while rest.count > targetSize * 2 {
                flush()
                let cut = rest.index(rest.startIndex, offsetBy: targetSize)
                // Prefer to cut at a space so words stay whole.
                let boundary = rest[..<cut].lastIndex(of: " ") ?? cut
                pieces.append(String(rest[..<boundary]).trimmingCharacters(in: .whitespaces))
                rest = rest[boundary...]
            }
            if current.count + rest.count + 1 > targetSize { flush() }
            current += rest + "\n"
        }
        flush()
        return pieces.enumerated().map { Segment(heading: heading($0.offset + 1), text: $0.element) }
    }
}
