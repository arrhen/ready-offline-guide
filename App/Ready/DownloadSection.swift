import SwiftUI
import ReadyCore

/// Download controls for the model currently picked on the setup screen.
struct DownloadSection: View {
    let model: ModelOption
    let onStart: () -> Void
    private var downloader = ModelDownloader.shared

    init(model: ModelOption, onStart: @escaping () -> Void) {
        self.model = model
        self.onStart = onStart
    }

    var body: some View {
        Section {
            if downloader.isInstalled(model) {
                Label("Installed. Works fully offline.", systemImage: "checkmark.circle.fill")
            } else {
                switch downloader.states[model.id] {
                case nil:
                    Button("Download \(model.name) (\(size))") { start() }
                case .downloading(let progress):
                    ProgressView(value: progress) { Text("Downloading \(percent(progress))") }
                    HStack {
                        Button("Pause") { downloader.pause(model) }
                        Spacer()
                        Button("Cancel", role: .destructive) { downloader.cancel(model) }
                    }
                    .buttonStyle(.borderless)
                case .paused(let progress):
                    ProgressView(value: progress) { Text("Paused at \(percent(progress))") }
                    HStack {
                        Button("Resume") { start() }
                        Spacer()
                        Button("Cancel", role: .destructive) { downloader.cancel(model) }
                    }
                    .buttonStyle(.borderless)
                case .verifying:
                    HStack {
                        ProgressView()
                        Text("Checking the file…").padding(.leading, 8)
                    }
                case .failed(let message):
                    Text(message).foregroundStyle(.red)
                    Button("Try again") { start() }
                }
            }
        } footer: {
            if !downloader.isInstalled(model) {
                Text(downloader.allowsCellular
                     ? "Downloads can use cellular data."
                     : "Downloads use Wi-Fi only. Change this in Settings.")
            }
        }
    }

    private var size: String {
        ByteCountFormatter.string(fromByteCount: model.downloadBytes, countStyle: .file)
    }

    private func percent(_ p: Double) -> String { "\(Int((p * 100).rounded()))%" }

    private func start() {
        onStart()
        downloader.start(model)
    }
}
