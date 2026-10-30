import SwiftUI
import ReadyCore

/// The guides that come with the app. Works with no model and no network.
struct LibraryView: View {
    private let pack = GuidePack.bundled()

    var body: some View {
        let guides = pack?.guides() ?? []
        List {
            if guides.isEmpty {
                Section {
                    Text("No guides are included in this build yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(guides) { guide in
                        NavigationLink {
                            GuideView(guide: guide, sections: pack?.sections(of: guide.id) ?? [])
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(guide.title).font(.headline)
                                Text("\(guide.publisher) · updated \(guide.sourceUpdated)")
                                    .font(.footnote).foregroundStyle(.secondary)
                                #if DEBUG
                                if !guide.isCleared {
                                    Text("Not cleared for release").font(.footnote).foregroundStyle(.orange)
                                }
                                #endif
                            }
                        }
                    }
                } footer: {
                    Text("Guides are reproduced from public sources and can be out of date. Check the source for anything that matters.")
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideView: View {
    let guide: Guide
    let sections: [GuideSection]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.heading) {
                    Text(section.body)
                        .textSelection(.enabled)
                }
            }
            Section("Source") {
                SourceCredit(guide: guide)
            }
        }
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Who a guide came from, when it was updated, and what we rely on to reproduce it.
struct SourceCredit: View {
    let guide: Guide

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(guide.publisher): \(guide.sourceTitle)")
            Text("Source last updated \(guide.sourceUpdated). Copied into Ready on \(guide.retrieved).")
                .font(.footnote).foregroundStyle(.secondary)
            Link("Open the original page", destination: guide.sourceURL)
                .font(.footnote)
            Text("Ready is not affiliated with or endorsed by \(guide.publisher). \(guide.licenseBasis)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
