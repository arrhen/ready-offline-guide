import SwiftUI
import ReadyCore

/// Emergency number wording for the device's region setting (not its location).
var emergencyNumberText: String {
    EmergencyNumber.phrase(forRegion: Locale.current.region?.identifier)
}

/// Shown on first launch, and again whenever the wording changes.
struct AcknowledgementView: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Before you start")
                        .font(.largeTitle.bold())
                    ForEach(Legal.keyPoints(emergency: emergencyNumberText), id: \.self) { point in
                        Label {
                            Text(point)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("The full notice is in Settings under About & legal.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            Button(action: onAccept) {
                Text("I understand")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .interactiveDismissDisabled()
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                ForEach(Legal.keyPoints(emergency: emergencyNumberText), id: \.self) { Text($0) }
            } header: {
                Text("Please remember")
            }
            ForEach(Legal.sections(emergency: emergencyNumberText), id: \.title) { section in
                Section(section.title) { Text(section.body) }
            }
            Section {
                if let url = Legal.reportURL(question: nil, answer: "(general feedback)") {
                    Link("Report a problem", destination: url)
                }
            }
        }
        .navigationTitle("About & legal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
