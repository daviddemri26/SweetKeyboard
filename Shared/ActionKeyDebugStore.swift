import Foundation

struct ActionKeyDebugSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let actionType: String
    let displayMode: String
    let visibleLabel: String
    let accessibilityLabel: String
    let debugDescription: String
    let returnKeyType: String?
    let keyboardType: String?
    let textContentType: String?
    let enablesReturnKeyAutomatically: Bool?
    let hasText: Bool
    let hasDocumentText: Bool
    let hasSelection: Bool
    let documentContextContainsLineBreaks: Bool

    var signature: String {
        [
            actionType,
            displayMode,
            visibleLabel,
            accessibilityLabel,
            debugDescription,
            returnKeyType ?? "-",
            keyboardType ?? "-",
            textContentType ?? "-",
            enablesReturnKeyAutomatically.map(String.init) ?? "-",
            String(hasText),
            String(hasDocumentText),
            String(hasSelection),
            String(documentContextContainsLineBreaks)
        ].joined(separator: "|")
    }
}

final class ActionKeyDebugStore {
    private enum Constants {
        static let defaultsKey = "action-key-debug-snapshots"
        static let maxSnapshots = 40
    }

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.userDefaults = userDefaults
    }

    func allSnapshots() -> [ActionKeyDebugSnapshot] {
        guard
            let userDefaults,
            let data = userDefaults.data(forKey: Constants.defaultsKey)
        else {
            return []
        }

        do {
            return try JSONDecoder().decode([ActionKeyDebugSnapshot].self, from: data)
        } catch {
            return []
        }
    }

    func record(_ snapshot: ActionKeyDebugSnapshot) {
        var snapshots = allSnapshots()
        guard snapshots.first?.signature != snapshot.signature else {
            return
        }

        snapshots.insert(snapshot, at: 0)
        if snapshots.count > Constants.maxSnapshots {
            snapshots.removeLast(snapshots.count - Constants.maxSnapshots)
        }

        persist(snapshots)
    }

    func clearAll() {
        persist([])
    }

    private func persist(_ snapshots: [ActionKeyDebugSnapshot]) {
        guard let userDefaults else {
            return
        }

        do {
            let data = try JSONEncoder().encode(snapshots)
            userDefaults.set(data, forKey: Constants.defaultsKey)
        } catch {
            return
        }
    }
}
