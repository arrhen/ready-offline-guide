import SwiftUI
import ReadyCore

struct StorageView: View {
    @Bindable private var downloader = ModelDownloader.shared
    @Environment(\.dismiss) private var dismiss
    @State private var free = DeviceProfile.current().freeStorageBytes

    private var installed: [ModelOption] {
        ModelCatalog.all.filter { downloader.isInstalled($0) }
    }

    private var used: Int64 {
        installed.reduce(0) { $0 + downloader.installedSize(of: $1) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Downloaded models") {
                    if installed.isEmpty {
                        Text("No models downloaded yet.").foregroundStyle(.secondary)
                    }
                    ForEach(installed) { model in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(model.tier.label): \(model.name)").font(.headline)
                                Spacer()
                                Text(bytes(downloader.installedSize(of: model))).foregroundStyle(.secondary)
                            }
                            Text("\(model.license) · \(model.source)")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { downloader.delete(installed[index]) }
                        free = DeviceProfile.current().freeStorageBytes
                    }
                }
                Section {
                    LabeledContent("Used by Ready", value: bytes(used))
                    LabeledContent("Free on this phone", value: bytes(free))
                } footer: {
                    Text("Swipe a model to delete it. You can download it again any time.")
                }
                Section {
                    Toggle("Download over cellular", isOn: $downloader.allowsCellular)
                } footer: {
                    Text("Models are large, so Wi-Fi is recommended.")
                }
            }
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}
