import Foundation

final class ClipboardStore {
    private enum Constants {
        static let storageKey = "clipboard.history.v1"
        static let maxItems = 50
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        // Fallback keeps local storage available even before entitlements are configured.
        self.defaults = defaults ?? .standard
    }

    func allItems() -> [ClipboardItem] {
        guard let data = defaults.data(forKey: Constants.storageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            return []
        }
    }

    func add(text: String, source: ClipboardItem.Source) {
        let normalized = normalize(text)
        guard !normalized.isEmpty else {
            return
        }

        var items = allItems()

        if items.first?.text == normalized {
            return
        }

        items.insert(ClipboardItem(text: normalized, source: source), at: 0)

        if items.count > Constants.maxItems {
            items = Array(items.prefix(Constants.maxItems))
        }

        save(items)
    }

    func clearAll() {
        defaults.removeObject(forKey: Constants.storageKey)
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save(_ items: [ClipboardItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            defaults.set(data, forKey: Constants.storageKey)
        } catch {
            return
        }
    }
}
