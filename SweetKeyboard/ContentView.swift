import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var manualClipboardText = ""
    @State private var history: [ClipboardItem] = []
    @State private var actionSnapshots: [ActionKeyDebugSnapshot] = []
    @State private var sharedSettings = SharedKeyboardSettings()
    @State private var capabilityStatus = KeyboardCapabilityStatus()

    private let clipboardStore = ClipboardStore()
    private let actionKeyDebugStore = ActionKeyDebugStore()
    private let sharedSettingsStore = SharedKeyboardSettingsStore()
    private let capabilityStatusStore = KeyboardCapabilityStatusStore()

    private var canEnableClipboardMode: Bool {
        capabilityStatus.lastConfirmedFullAccessAt != nil
    }

    var body: some View {
        NavigationStack {
            List {
                keyboardSetupSection
                keyboardFeaturesSection
                keyboardFeedbackSection
                privacySection
                clipboardDebugSection
                actionKeyDebugSection
                platformNotesSection
            }
            .navigationTitle("SweetKeyboard")
            .onAppear(perform: reloadState)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                reloadState()
            }
        }
    }

    private var keyboardSetupSection: some View {
        Section("Keyboard Setup") {
            Text("1. Open Settings > General > Keyboard > Keyboards.")
            Text("2. Tap Add New Keyboard and choose SweetKeyboard.")
            Text("3. Basic typing works right away.")
            Text("4. If you want clipboard tools, open the SweetKeyboard keyboard entry and enable Allow Full Access.")
        }
    }

    private var keyboardFeaturesSection: some View {
        Section("Keyboard Features") {
            Text("Basic typing works right away. Clipboard tools require Full Access.")
                .foregroundStyle(.secondary)

            Toggle(
                "Clipboard toolbar",
                isOn: Binding(
                    get: { sharedSettings.clipboardModeEnabled },
                    set: { newValue in
                        guard canEnableClipboardMode || !newValue else {
                            return
                        }

                        sharedSettings.clipboardModeEnabled = newValue
                        sharedSettingsStore.setClipboardModeEnabled(newValue)
                    }
                )
            )
            .disabled(!canEnableClipboardMode && !sharedSettings.clipboardModeEnabled)

            Text("When on, SweetKeyboard shows Copy, Paste, Clipboard, and Settings above the keyboard.")
                .foregroundStyle(.secondary)

            if !canEnableClipboardMode {
                Text("To turn on Clipboard mode, enable Full Access for SweetKeyboard in iPhone Settings, then open the keyboard once.")
                    .foregroundStyle(.secondary)
            } else if !sharedSettings.clipboardModeEnabled {
                Text("Clipboard toolbar is currently off. Basic mode keeps the keyboard compact while preserving the number row and normal typing.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Text("Clipboard data stays on this device. No network, no analytics, no cloud sync.")
            Text("SweetKeyboard uses Full Access only for local clipboard and shared settings features.")
                .foregroundStyle(.secondary)
        }
    }

    private var keyboardFeedbackSection: some View {
        Section("Keyboard Feedback") {
            Toggle(
                "Key haptics",
                isOn: Binding(
                    get: { sharedSettings.keyHapticsEnabled },
                    set: { newValue in
                        sharedSettings.keyHapticsEnabled = newValue
                        sharedSettingsStore.setKeyHapticsEnabled(newValue)
                    }
                )
            )

            Text("Adds a light haptic on letters, function keys, and clipboard actions when the device supports it.")
                .foregroundStyle(.secondary)
        }
    }

    private var clipboardDebugSection: some View {
        Section("Clipboard Debug") {
            Text("Local clipboard history used by the optional clipboard toolbar.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Manual import text", text: $manualClipboardText)
                .textInputAutocapitalization(.never)

            Button("Add to Local History") {
                let trimmed = manualClipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                clipboardStore.add(text: trimmed, source: .manualImport)
                manualClipboardText = ""
                reloadState()
            }

            Button("Clear History", role: .destructive) {
                clipboardStore.clearAll()
                reloadState()
            }

            if history.isEmpty {
                Text("No local clipboard items yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.text)
                            .lineLimit(2)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var actionKeyDebugSection: some View {
        Section("Action Key Debug") {
            Text("Recent trait snapshots recorded by the keyboard extension. The log excludes typed text and stores only action-key metadata.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Clear Action Key Log", role: .destructive) {
                actionKeyDebugStore.clearAll()
                reloadState()
            }

            if actionSnapshots.isEmpty {
                Text("No action-key observations yet. Use SweetKeyboard in a few apps and fields, then return here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(actionSnapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(snapshot.accessibilityLabel) · \(snapshot.displayMode)")
                            .font(.headline)

                        Text(snapshot.debugDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(snapshotSummary(snapshot))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var platformNotesSection: some View {
        Section("Platform Notes") {
            Text("Third-party keyboards are unavailable in secure text fields and some restricted input contexts.")
            Text("Copy works only when the active text field exposes selected text to the keyboard extension.")
            Text("If Full Access is off, SweetKeyboard automatically stays in typing-only mode.")
        }
    }

    private func reloadState() {
        history = clipboardStore.allItems()
        actionSnapshots = actionKeyDebugStore.allSnapshots()
        sharedSettings = sharedSettingsStore.load()
        capabilityStatus = capabilityStatusStore.load()
    }

    private func snapshotSummary(_ snapshot: ActionKeyDebugSnapshot) -> String {
        let returnKey = snapshot.returnKeyType ?? "unavailable"
        let keyboardType = snapshot.keyboardType ?? "unavailable"
        let textContentType = snapshot.textContentType ?? "nil"
        let autoReturn = snapshot.enablesReturnKeyAutomatically.map(String.init) ?? "nil"

        return "returnKeyType=\(returnKey)  keyboardType=\(keyboardType)  textContentType=\(textContentType)  autoReturn=\(autoReturn)  hasText=\(snapshot.hasText)  hasDocumentText=\(snapshot.hasDocumentText)"
    }
}

#Preview {
    ContentView()
}
