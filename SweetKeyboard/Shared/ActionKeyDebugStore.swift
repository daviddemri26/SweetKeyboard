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
}

final class ActionKeyDebugStore {
    private enum Constants {
        static let defaultsKey = "action-key-debug-snapshots"
    }

    private let userDefaults = UserDefaults(suiteName: AppGroup.identifier)

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

    func clearAll() {
        userDefaults?.removeObject(forKey: Constants.defaultsKey)
    }
}
