import SwiftUI
import ReadyCore

/// A passage from a file the person added. It carries no licence or review claim: it is theirs.
struct UserPassageView: View {
    let passage: UserPassage
    @State private var expanded: Bool

    init(passage: UserPassage, startsOpen: Bool) {
        self.passage = passage
        _expanded = State(initialValue: startsOpen)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                // Not selectable: the text menu offers Copy and Share, and Ready adds no way to send a person's files out.
                Text(passage.body)
                Text("From a file you added on \(passage.addedAt.formatted(date: .abbreviated, time: .omitted)). It hasn't been reviewed, and its contents are your responsibility.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .font(.footnote)
        } label: {
            Label("From your files: \(passage.documentTitle), \(passage.heading)", systemImage: "doc.on.doc")
                .font(.footnote)
        }
    }
}
