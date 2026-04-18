import SwiftUI

struct ContentView: View {
    @State private var manualClipboardText = ""
    @State private var history: [ClipboardItem] = []

    private let store = ClipboardStore()

    var body: some View {
        NavigationStack {
            List {
                setupSection
                privacySection
                debugSection
                limitationsSection
            }
            .navigationTitle("SweetKeyboard")
            .onAppear(perform: reloadHistory)
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
                reloadHistory()
            }

            Button("Clear History", role: .destructive) {
                store.clearAll()
                reloadHistory()
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

    private var limitationsSection: some View {
        Section("Platform Limitations") {
            Text("Third-party keyboards are unavailable in secure text fields and some restricted input contexts.")
            Text("Copy only works when the active text field exposes selected text to the keyboard extension.")
        }
    }

    private func reloadHistory() {
        history = store.allItems()
    }
}

#Preview {
    ContentView()
}
