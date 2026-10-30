import SwiftUI
import ReadyCore

struct ChatView: View {
    let model: ModelOption
    let settings: Settings
    /// A question to answer as soon as the model has loaded, when opened from a search.
    var initialQuestion: String?

    @State private var session = ChatSession()
    @State private var draft = ""
    @State private var sentInitial = false
    @FocusState private var focused: Bool
    @Environment(\.scenePhase) private var scenePhase

    #if targetEnvironment(simulator)
    private let useGPU = false
    #else
    private let useGPU = true
    #endif

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text("Answers come from a small model and can be wrong. In an emergency, call your local emergency number.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(session.messages) { message in
                            bubble(message)
                        }
                        statusRow
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: session.messages.last?.content) { proxy.scrollTo("end") }
                .onChange(of: session.messages.count) { proxy.scrollTo("end") }
            }
            inputBar
        }
        .navigationTitle("Short answer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("New chat") { session.clear() }
                .disabled(session.messages.isEmpty)
        }
        // Only the background frees the model. Control Center, the app switcher and call
        // banners make the app inactive for a moment and shouldn't interrupt an answer.
        .task(id: scenePhase == .background) {
            if scenePhase == .background {
                session.unload()
            } else {
                await session.load(model: model, settings: settings, useGPU: useGPU)
                if let question = initialQuestion, !sentInitial, session.status == .ready {
                    sentInitial = true
                    session.send(question)
                }
            }
        }
        .onDisappear { session.unload() }
    }

    @ViewBuilder private var statusRow: some View {
        switch session.status {
        case .loading:
            HStack { ProgressView(); Text("Loading \(model.name)…").padding(.leading, 8) }
                .foregroundStyle(.secondary)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).foregroundStyle(.red)
                Button("Try again") { Task { await session.load(model: model, settings: settings, useGPU: useGPU) } }
            }
        default:
            EmptyView()
        }
        if let error = session.answerError {
            Text(error).font(.footnote).foregroundStyle(.red)
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.role == .assistant, !message.sources.isEmpty, !message.content.isEmpty {
                Label("Machine-written summary. Check the guide text below.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            bubbleText(message)
            ForEach(Array(message.sources.enumerated()), id: \.element.id) { index, passage in
                SourcePassageView(passage: passage, startsOpen: index == 0)
            }
            if !message.sources.isEmpty, !message.content.isEmpty {
                Text("The summary above was written by a small model and can be wrong. The guide text is what to rely on.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func bubbleText(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 40) }
            Text(rendered(message))
                .padding(10)
                .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .textSelection(.enabled)
                .contextMenu {
                    if !isUser, !message.content.isEmpty,
                       let url = Legal.reportURL(question: question(before: message), answer: message.content) {
                        Link(destination: url) { Label("Report this answer", systemImage: "flag") }
                    }
                }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private func question(before message: ChatMessage) -> String? {
        guard let index = session.messages.firstIndex(where: { $0.id == message.id }), index > 0 else { return nil }
        return session.messages[index - 1].content
    }

    /// Small models answer in Markdown, so show bold and italics instead of raw asterisks. Links and
    /// images are removed: nothing the model writes may be tappable (see SafeMarkdown).
    private func rendered(_ message: ChatMessage) -> AttributedString {
        SafeMarkdown.render(message.content)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask a follow-up", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if session.status == .generating {
                Button { session.stop() } label: {
                    Image(systemName: "stop.circle.fill").font(.title)
                }
                .accessibilityLabel("Stop")
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .accessibilityLabel("Send")
                .disabled(session.status != .ready || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send() {
        session.send(draft)
        draft = ""
    }
}

/// A guide passage under an answer. The first one starts open so the real text is seen first.
struct SourcePassageView: View {
    let passage: Passage
    @State private var expanded: Bool

    init(passage: Passage, startsOpen: Bool) {
        self.passage = passage
        _expanded = State(initialValue: startsOpen)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                Text(passage.section.body).textSelection(.enabled)
                SourceCredit(guide: passage.guide)
            }
            .font(.footnote)
        } label: {
            Label("From the guide: \(passage.guide.title), \(passage.section.heading)", systemImage: "doc.text")
                .font(.footnote)
        }
    }
}
