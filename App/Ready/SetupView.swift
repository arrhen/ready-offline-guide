import SwiftUI
import ReadyCore

struct SetupView: View {
    @State private var device = DeviceProfile.current()
    @AppStorage("selectedModelID") private var selectedModelID = ""
    @AppStorage("selectedPreset") private var selectedPresetRaw = -1
    @State private var chosenID: String?

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
                            Button { chosenID = option.id } label: {
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
                    Section {
                        Button(selectedModelID == choice.id ? "Selected" : "Use \(choice.name)") {
                            selectedModelID = choice.id
                        }
                        .disabled(selectedModelID == choice.id)
                    } footer: {
                        if selectedModelID == choice.id {
                            Text("Downloading arrives in the next update.")
                        }
                    }
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
            .onAppear { device = DeviceProfile.current() }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private func modelRow(_ option: ModelOption, picked: Bool, recommended: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(option.tier.label): \(option.name)").font(.headline)
                Text(recommended ? "Recommended for your phone · \(option.license)" : option.license)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(bytes(option.downloadBytes)).foregroundStyle(.secondary)
            Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(picked ? Color.accentColor : Color.secondary)
        }
        .contentShape(Rectangle())
    }

    private func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}

#Preview { SetupView() }
