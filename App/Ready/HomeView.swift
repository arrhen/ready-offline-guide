import SwiftUI
import ReadyCore

/// The first screen. One question field, then the guides themselves. It works with no model and
/// no network: it searches the guides on the phone and shows the passages with their source.
struct HomeView: View {
    private let pack = GuidePack.bundled()

    @State private var query = ""
    @State private var asked = ""
    @State private var result: LookupResult?
    @State private var showSettings = false
    @FocusState private var fieldFocused: Bool

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
                if let result { resultSection(result) }
                guidesSection(guides)
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
            .sheet(isPresented: $showSettings) { SettingsView() }
            #if DEBUG
            .onAppear { device = DeviceProfile.current() }
            #endif
        }
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
                        result = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
        } footer: {
            Text("Searches the guides on this phone. Nothing leaves it.")
        }
    }

    private func ask() {
        let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        asked = question
        result = pack?.lookup(question) ?? .noMatch
        fieldFocused = false
    }

    @ViewBuilder private func resultSection(_ result: LookupResult) -> some View {
        switch result {
        case .emergency:
            Section {
                Label {
                    Text(SafetyScreen.reply(emergency: emergencyNumberText))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        case .noMatch:
            Section {
                Text(ChatSession.noGuideReply(emergency: emergencyNumberText))
            }
        case .passages(let passages):
            Section {
                ForEach(Array(passages.enumerated()), id: \.element.id) { index, passage in
                    SourcePassageView(passage: passage, startsOpen: index == 0)
                }
                #if DEBUG
                if let model = selection.installed(in: downloader) {
                    NavigationLink("Short answer (preview)") {
                        ChatView(model: model, settings: selection.settings, initialQuestion: asked)
                    }
                }
                #endif
            } header: {
                Text("From the guides")
            } footer: {
                Text("This is the text of the guide. Check the source for anything that matters.")
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

    // MARK: Preview-only model row

    #if DEBUG
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
