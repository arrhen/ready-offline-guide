import SwiftUI
import ReadyCore

/// One guide in a list: title, who published it, and when that source was last updated.
struct GuideRow: View {
    let guide: Guide

    var body: some View {
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
            Text("Source last updated \(guide.sourceUpdated). Copied on \(guide.retrieved).")
                .font(.footnote).foregroundStyle(.secondary)
            Link("Open the original page", destination: guide.sourceURL)
                .font(.footnote)
            Text("This app is not affiliated with or endorsed by \(guide.publisher). \(guide.licenseBasis)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
