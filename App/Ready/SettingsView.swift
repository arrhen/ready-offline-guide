import SwiftUI
import ReadyCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearanceRaw = AppearanceChoice.system.rawValue
    #if DEBUG
    // Models only exist in preview builds, so release builds never start the download session.
    @Bindable private var downloader = ModelDownloader.shared
    @State private var free = DeviceProfile.current().freeStorageBytes
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(AppearanceChoice.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows your phone's light or dark setting.")
                }

                #if DEBUG
                modelSections
                #endif

                Section {
                    NavigationLink("About & legal") { AboutView() }
                    NavigationLink("Support Ready") { TipJarView() }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    #if DEBUG
    private var installed: [ModelOption] {
        ModelCatalog.all.filter { downloader.isInstalled($0) }
    }

    private var used: Int64 {
        installed.reduce(0) { $0 + downloader.installedSize(of: $1) }
    }

    @ViewBuilder private var modelSections: some View {
        Section {
            if installed.isEmpty {
                Text("No models downloaded.").foregroundStyle(.secondary)
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
            LabeledContent("Used", value: bytes(used))
            LabeledContent("Free on this phone", value: bytes(free))
        } header: {
            Text("Downloaded models")
        } footer: {
            Text("Swipe a model to delete it. You can download it again any time.")
        }
        Section {
            Toggle("Download over cellular", isOn: $downloader.allowsCellular)
        } footer: {
            Text("Models are large, so Wi-Fi is recommended.")
        }
    }

    private func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
    #endif
}
