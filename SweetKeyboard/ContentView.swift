import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var manualClipboardText = ""
    @State private var history: [ClipboardItem] = []
    @State private var actionSnapshots: [ActionKeyDebugSnapshot] = []

    private let store = ClipboardStore()
    private let actionKeyDebugStore = ActionKeyDebugStore()

    var body: some View {
        NavigationStack {
            List {
                setupSection
                privacySection
                debugSection
                actionKeyDebugSection
                limitationsSection
            }
            .navigationTitle("SweetKeyboard")
            .onAppear(perform: reloadDebugState)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                reloadDebugState()
            }
        }
    }

    private var setupSection: some View {
        Section("Enable Keyboard") {
            Text("1. Open Settings > General > Keyboard > Keyboards")
            Text("2. Tap Add New Keyboard and choose SweetKeyboard")
            Text("3. Tap SweetKeyboard and enable Allow Full Access")
        }
    }

    private var privacySection: some View {
        Section("Why Full Access") {
            Text("SweetKeyboard needs Full Access to read/write system pasteboard and persist clipboard history in an App Group shared container.")
            Text("All data remains local on your device.")
            Text("No network calls, no analytics, no cloud sync, no keystroke upload.")
        }
    }

    private var debugSection: some View {
        Section("Clipboard Debug") {
            TextField("Manual import text", text: $manualClipboardText)
                .textInputAutocapitalization(.never)

            Button("Add to Local History") {
                let trimmed = manualClipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                store.add(text: trimmed, source: .manualImport)
                manualClipboardText = ""
                reloadDebugState()
            }

            Button("Clear History", role: .destructive) {
                store.clearAll()
                reloadDebugState()
            }

            if history.isEmpty {
                Text("No local clipboard items yet")
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
                reloadDebugState()
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

    private var limitationsSection: some View {
        Section("Platform Limitations") {
            Text("Third-party keyboards are unavailable in secure text fields and some restricted input contexts.")
            Text("Copy only works when the active text field exposes selected text to the keyboard extension.")
        }
    }

    private func reloadDebugState() {
        history = store.allItems()
        actionSnapshots = actionKeyDebugStore.allSnapshots()
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
