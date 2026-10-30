import SwiftUI
import ReadyCore

/// Which model and settings the phone should use. Shared by the home screen and this screen.
struct ModelSelection {
    let device: DeviceProfile
    let selectedModelID: String
    let selectedPresetRaw: Int

    var ramClass: RAMClass { RAMClass(physicalMemoryBytes: device.physicalMemoryBytes) }
    var recommendation: Recommendation { Recommender.recommend(for: device) }
    var options: [ModelOption] { [recommendation.primary].compactMap { $0 } + recommendation.alternatives }

    var preset: Preset { Preset(rawValue: selectedPresetRaw) ?? recommendation.settings.preset }
    var effectivePreset: Preset { Recommender.effectivePreset(base: preset, device: device) }
    var settings: Settings { Recommender.settings(for: effectivePreset, ramClass: ramClass) }

    /// The model picked on screen: the saved choice, else the recommendation.
    func current(chosenID: String? = nil) -> ModelOption? {
        options.first { $0.id == chosenID }
            ?? options.first { $0.id == selectedModelID }
            ?? recommendation.primary
    }

    /// The model short answers should use: the picked one if installed, else the largest installed.
    @MainActor func installed(in downloader: ModelDownloader) -> ModelOption? {
        if let choice = current(), downloader.isInstalled(choice) { return choice }
        return options.filter { downloader.isInstalled($0) }.max { $0.tier < $1.tier }
    }
}

/// Model download and phone settings. Preview builds only, because release builds have nothing
/// that uses a model yet.
struct ModelsView: View {
    @State private var device = DeviceProfile.current()
    @AppStorage("selectedModelID") private var selectedModelID = ""
    @AppStorage("selectedPreset") private var selectedPresetRaw = -1
    @State private var chosenID: String?
    private var downloader = ModelDownloader.shared

    private var selection: ModelSelection {
        ModelSelection(device: device, selectedModelID: selectedModelID, selectedPresetRaw: selectedPresetRaw)
    }

    var body: some View {
        let selection = selection
        List {
            Section("Your phone") {
                LabeledContent("Memory", value: "\(selection.ramClass.rawValue) GB class")
                LabeledContent("Free space", value: bytes(device.freeStorageBytes))
                if device.isLowPowerMode { LabeledContent("Power", value: "Low Power Mode on") }
            }

            if let choice = selection.current(chosenID: chosenID) {
                Section {
                    ForEach(selection.options) { option in
                        Button { chosenID = option.id; selectedModelID = option.id } label: {
                            modelRow(option, picked: option.id == choice.id,
                                     recommended: option.id == selection.recommendation.primary?.id)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Model")
                } footer: {
                    Text("A bigger model writes better short answers but uses more space and battery.")
                }

                Section {
                    Picker("Answer style", selection: Binding(get: { selection.preset },
                                                              set: { selectedPresetRaw = $0.rawValue })) {
                        ForEach(Preset.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if selection.effectivePreset != selection.preset {
                        Text("Using \(selection.effectivePreset.label) for now to save power and heat.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    DisclosureGroup("Advanced") {
                        LabeledContent("Context", value: "\(selection.settings.contextLength) tokens")
                        LabeledContent("Answer length", value: "up to \(selection.settings.maxAnswerTokens) tokens")
                    }
                } header: {
                    Text("Answer style")
                } footer: {
                    Text("Battery saver gives shorter answers and runs cooler. Best quality is slower and uses more battery.")
                }

                DownloadSection(model: choice) { selectedModelID = choice.id }
            } else {
                Section {
                    Text("There isn't enough free space for a model. The guides still work without one.")
                }
            }

            ForEach(selection.recommendation.notes, id: \.self) { note in
                Section { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Model & phone")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { device = DeviceProfile.current() }
        .onChange(of: downloader.installedIDs) { device = DeviceProfile.current() }
    }

    private func modelRow(_ option: ModelOption, picked: Bool, recommended: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(option.tier.label): \(option.name)").font(.headline)
                Text(subtitle(option, recommended: recommended))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(bytes(option.downloadBytes)).foregroundStyle(.secondary)
            Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(picked ? Color.accentColor : Color.secondary)
        }
        .contentShape(Rectangle())
    }

    private func subtitle(_ option: ModelOption, recommended: Bool) -> String {
        var parts: [String] = []
        if downloader.isInstalled(option) {
            parts.append("Installed")
        } else if let state = downloader.states[option.id] {
            switch state {
            case .downloading(let p): parts.append("Downloading \(Int((p * 100).rounded()))%")
            case .paused: parts.append("Paused")
            case .verifying: parts.append("Checking")
            case .failed: parts.append("Download failed")
            }
        }
        if recommended { parts.append("Recommended for your phone") }
        parts.append(option.license)
        return parts.joined(separator: " · ")
    }

    private func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}
