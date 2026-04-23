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
        orderedItems(loadItems())
    }

    @discardableResult
    func add(text: String, source: ClipboardItem.Source) -> Bool {
        guard !text.isEmpty else {
            return false
        }

        var items = allItems()
        let newestUnpinnedItem = items.first { !$0.isPinned }
        let newestComparableItem = newestUnpinnedItem ?? items.first

        if newestComparableItem?.text.hasSameUTF8Bytes(as: text) == true {
            return false
        }

        let firstUnpinnedIndex = items.firstIndex { !$0.isPinned } ?? items.endIndex
        items.insert(ClipboardItem(text: text, source: source), at: firstUnpinnedIndex)

        return save(trimmedItems(items))
    }

    @discardableResult
    func delete(id: ClipboardItem.ID) -> Bool {
        var items = allItems()
        let originalCount = items.count
        items.removeAll { $0.id == id }

        guard items.count != originalCount else {
            return false
        }

        return save(items)
    }

    @discardableResult
    func setPinned(id: ClipboardItem.ID, isPinned: Bool, pinnedAt: Date = Date()) -> Bool {
        var items = allItems()

        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].isPinned != isPinned else {
            return false
        }

        items[index] = items[index].withPinState(
            isPinned: isPinned,
            pinnedAt: isPinned ? pinnedAt : nil
        )

        return save(trimmedItems(items))
    }

    func clearAll() {
        defaults.removeObject(forKey: Constants.storageKey)
    }

    private func loadItems() -> [ClipboardItem] {
        guard let data = defaults.data(forKey: Constants.storageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            return []
        }
    }

    private func orderedItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element
                let right = rhs.element

                if left.isPinned != right.isPinned {
                    return left.isPinned
                }

                if left.isPinned {
                    let leftPinnedAt = left.pinnedAt ?? left.createdAt
                    let rightPinnedAt = right.pinnedAt ?? right.createdAt

                    if leftPinnedAt != rightPinnedAt {
                        return leftPinnedAt > rightPinnedAt
                    }
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func trimmedItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        let orderedItems = orderedItems(items)

        if orderedItems.count > Constants.maxItems {
            return Array(orderedItems.prefix(Constants.maxItems))
        }

        return orderedItems
    }

    private func save(_ items: [ClipboardItem]) -> Bool {
        do {
            let data = try JSONEncoder().encode(items)
            defaults.set(data, forKey: Constants.storageKey)
            return true
        } catch {
            return false
        }
    }
}
