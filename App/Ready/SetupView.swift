import SwiftUI
import ReadyCore

struct SetupView: View {
    @State private var device = DeviceProfile.current()
    @AppStorage("selectedModelID") private var selectedModelID = ""
    @AppStorage("selectedPreset") private var selectedPresetRaw = -1
    @State private var chosenID: String?
    @State private var showStorage = false
    private var downloader = ModelDownloader.shared

    private var ramClass: RAMClass { RAMClass(physicalMemoryBytes: device.physicalMemoryBytes) }
    private var recommendation: Recommendation { Recommender.recommend(for: device) }

    private var preset: Preset {
        Preset(rawValue: selectedPresetRaw) ?? recommendation.settings.preset
    }

    private var effective: Preset { Recommender.effectivePreset(base: preset, device: device) }
    private var settings: Settings { Recommender.settings(for: effective, ramClass: ramClass) }

    private var allOptions: [ModelOption] {
        [recommendation.primary].compactMap { $0 } + recommendation.alternatives
    }

    private var currentChoice: ModelOption? {
        allOptions.first { $0.id == chosenID }
            ?? allOptions.first { $0.id == selectedModelID }
            ?? recommendation.primary
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Your phone") {
                    row("Memory", "\(ramClass.rawValue) GB class")
                    row("Free space", bytes(device.freeStorageBytes))
                    if device.isLowPowerMode { row("Power", "Low Power Mode on") }
                }

                if let choice = currentChoice {
                    Section("Models") {
                        ForEach(allOptions) { option in
                            Button { chosenID = option.id; selectedModelID = option.id } label: {
                                modelRow(option, picked: option.id == choice.id,
                                         recommended: option.id == recommendation.primary?.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Section {
                        Picker("Preset", selection: Binding(get: { preset }, set: { selectedPresetRaw = $0.rawValue })) {
                            ForEach(Preset.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        row("Context", "\(settings.contextLength) tokens")
                        row("Answer length", "up to \(settings.maxAnswerTokens) tokens")
                        if effective != preset {
                            Text("Using \(effective.label) for now to save power and heat.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Settings")
                    } footer: {
                        Text("You can change these any time.")
                    }
                    DownloadSection(model: choice, settings: settings) { selectedModelID = choice.id }
                } else {
                    Section {
                        Text("There isn't enough free space for a model. The Library still works without one.")
                    }
                }

                ForEach(recommendation.notes, id: \.self) { note in
                    Section { Text(note).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Ready")
            .toolbar {
                Button("Settings") { showStorage = true }
            }
            .sheet(isPresented: $showStorage, onDismiss: { device = DeviceProfile.current() }) {
                StorageView()
            }
            .onAppear { device = DeviceProfile.current() }
            .onChange(of: downloader.installedIDs) { device = DeviceProfile.current() }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
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

#Preview { SetupView() }
