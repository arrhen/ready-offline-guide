import SwiftUI
import UniformTypeIdentifiers
import ReadyCore

/// The first screen. One question field, then the guides and the person's own files. It works with no
/// model and no network: it searches the text on the phone and shows the passages with their source.
struct HomeView: View {
    private let pack = GuidePack.bundled()
    private let library = UserLibrary.shared

    @State private var query = ""
    @State private var asked = ""
    @State private var findings: Findings?
    @State private var showSettings = false
    @FocusState private var fieldFocused: Bool

    // Your files
    @State private var documents: [UserDocument] = []
    @State private var showNotice = false
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var importMessages: [String] = []
    @AppStorage("importAckVersion") private var importAckVersion = 0

    #if DEBUG
    @State private var device = DeviceProfile.current()
    @AppStorage("selectedModelID") private var selectedModelID = ""
    @AppStorage("selectedPreset") private var selectedPresetRaw = -1
    private var downloader = ModelDownloader.shared

    private var selection: ModelSelection {
        ModelSelection(device: device, selectedModelID: selectedModelID, selectedPresetRaw: selectedPresetRaw)
    }
    #endif

    var body: some View {
        let guides = pack?.guides() ?? []
        NavigationStack {
            List {
                questionSection
                if let findings { resultSections(findings) }
                guidesSection(guides)
                filesSection
                #if DEBUG
                previewSection
                #endif
            }
            .navigationTitle("Ready")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: reloadDocuments) { SettingsView() }
            .alert("Before you add files", isPresented: $showNotice) {
                Button("Choose files") {
                    importAckVersion = Legal.importNoticeVersion
                    showImporter = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(Legal.importNotice)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: Self.allowedTypes,
                          allowsMultipleSelection: true, onCompletion: handleImport)
            .onAppear {
                reloadDocuments()
                #if DEBUG
                device = DeviceProfile.current()
                #endif
            }
        }
    }

    /// Local files only. The picker is the only way a file gets in.
    private static var allowedTypes: [UTType] {
        [.plainText, .pdf] + [UTType("net.daringfireball.markdown")].compactMap { $0 }
    }

    // MARK: Question

    private var questionSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("What do you need to know?", text: $query)
                    .focused($fieldFocused)
                    .submitLabel(.search)
                    .onSubmit(ask)
                if !query.isEmpty {
                    Button {
                        query = ""
                        asked = ""
                        findings = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
        } footer: {
            Text("Searches the guides and your files on this phone. Nothing leaves it.")
        }
    }

    private func ask() {
        let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        asked = question
        findings = Lookup.run(question, pack: pack, library: library)
        fieldFocused = false
    }

    @ViewBuilder private func resultSections(_ findings: Findings) -> some View {
        if findings.isEmergency {
            Section {
                Label {
                    Text(SafetyScreen.reply(emergency: emergencyNumberText))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        } else if findings.isEmpty {
            Section {
                Text(ChatSession.noGuideReply(emergency: emergencyNumberText))
            }
        } else {
            if findings.needsCaution {
                Section {
                    Label {
                        Text(SafetyScreen.cautionNote(emergency: emergencyNumberText))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
            }
            if !findings.guides.isEmpty {
                Section {
                    ForEach(Array(findings.guides.enumerated()), id: \.element.id) { index, passage in
                        SourcePassageView(passage: passage, startsOpen: index == 0)
                    }
                    #if DEBUG
                    if !findings.needsCaution { shortAnswerLink }
                    #endif
                } header: {
                    Text("From the guides")
                } footer: {
                    Text("This is the text of the guide. Check the source for anything that matters.")
                }
            }
            if !findings.yours.isEmpty {
                Section {
                    ForEach(Array(findings.yours.enumerated()), id: \.element.id) { index, passage in
                        UserPassageView(passage: passage, startsOpen: index == 0 && findings.guides.isEmpty)
                    }
                    #if DEBUG
                    if findings.guides.isEmpty, !findings.needsCaution { shortAnswerLink }
                    #endif
                } header: {
                    Text("From your files")
                } footer: {
                    Text("From files you added. Ready hasn't reviewed them.")
                }
            }
        }
    }

    // MARK: Guides

    @ViewBuilder private func guidesSection(_ guides: [Guide]) -> some View {
        Section {
            if guides.isEmpty {
                Text("No guides are included in this build yet.").foregroundStyle(.secondary)
            }
            ForEach(guides) { guide in
                NavigationLink {
                    GuideView(guide: guide, sections: pack?.sections(of: guide.id) ?? [])
                } label: {
                    GuideRow(guide: guide)
                }
            }
        } header: {
            Text("Guides")
        } footer: {
            if !guides.isEmpty {
                Text("Reproduced from public sources. They can be out of date.")
            }
        }
    }

    // MARK: Your files

    private var filesSection: some View {
        Section {
            ForEach(documents) { document in
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title).font(.headline)
                    Text("\(document.passageCount) \(document.passageCount == 1 ? "passage" : "passages") · added \(document.addedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for index in offsets { library?.remove(documents[index]) }
                reloadDocuments()
            }
            Button(action: addFilesTapped) {
                Label("Add files", systemImage: "plus")
            }
            .disabled(isImporting || library == nil)
            if isImporting {
                HStack { ProgressView(); Text("Reading…").padding(.leading, 8) }
                    .foregroundStyle(.secondary)
            }
            ForEach(importMessages, id: \.self) { message in
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Your files")
        } footer: {
            Text("Text, Markdown and PDF files. Only the text is kept, on this phone. Swipe a file to remove it.")
        }
    }

    private func reloadDocuments() {
        documents = library?.documents() ?? []
    }

    private func addFilesTapped() {
        if importAckVersion < Legal.importNoticeVersion {
            showNotice = true
        } else {
            showImporter = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }
        isImporting = true
        importMessages = []
        Task {
            var messages: [String] = []
            for url in urls {
                messages.append(await importOne(url))
            }
            importMessages = messages
            isImporting = false
            reloadDocuments()
        }
    }

    private func importOne(_ url: URL) async -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let imported = try await Task.detached(priority: .userInitiated) { try FileImporter.read(url) }.value
            guard let library else { throw ImportError.unreadable }
            try library.add(imported)
            return "\(imported.title): added"
        } catch {
            return "\(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    // MARK: Preview-only model row

    #if DEBUG
    @ViewBuilder private var shortAnswerLink: some View {
        if let model = selection.installed(in: downloader) {
            NavigationLink("Short answer (preview)") {
                ChatView(model: model, settings: selection.settings, initialQuestion: asked)
            }
        }
    }

    private var previewSection: some View {
        Section {
            NavigationLink { ModelsView() } label: {
                if let model = selection.installed(in: downloader) {
                    Label("Short answers: \(model.name) installed", systemImage: "checkmark.circle")
                } else {
                    Label("Short answers: download a model", systemImage: "arrow.down.circle")
                }
            }
        } footer: {
            Text("Preview build. Short answers are not in the App Store version until the guides are reviewed.")
        }
    }
    #endif
}
