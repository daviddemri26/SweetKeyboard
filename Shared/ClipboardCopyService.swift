import Foundation

protocol ClipboardTextPasteboard: AnyObject {
    var string: String? { get set }
}

protocol ClipboardReadablePasteboard: AnyObject {
    var changeCount: Int { get }
    var hasStrings: Bool { get }
    var string: String? { get }
}

struct ClipboardCopyService {
    func copySelectedText(_ text: String, to pasteboard: ClipboardTextPasteboard) -> Bool {
        guard !text.isEmpty else {
            return false
        }

        pasteboard.string = text

        guard let copiedText = pasteboard.string else {
            return false
        }

        return copiedText.hasSameUTF8Bytes(as: text)
    }
}

struct ClipboardSystemImportContext {
    let isFullAccessAvailable: Bool
    let isClipboardModeEnabled: Bool
}

enum ClipboardSystemImportResult: Equatable {
    case unavailable
    case alreadyProcessed
    case noText
    case emptyText
    case stored
    case duplicate
}

final class ClipboardSystemImportService {
    private enum Constants {
        static let lastProcessedChangeCountKey = "clipboard.systemImport.lastProcessedChangeCount.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        // Fallback keeps the processed marker available before App Group setup is complete.
        self.defaults = defaults ?? .standard
    }

    func hasAvailableText(
        in pasteboard: ClipboardReadablePasteboard,
        context: ClipboardSystemImportContext
    ) -> Bool {
        guard context.isFullAccessAvailable,
              context.isClipboardModeEnabled else {
            return false
        }

        let changeCount = pasteboard.changeCount
        guard lastProcessedChangeCount != changeCount else {
            return false
        }

        return pasteboard.hasStrings
    }

    func importAvailableText(
        from pasteboard: ClipboardReadablePasteboard,
        into store: ClipboardStore,
        context: ClipboardSystemImportContext
    ) -> ClipboardSystemImportResult {
        guard context.isFullAccessAvailable,
              context.isClipboardModeEnabled else {
            return .unavailable
        }

        let changeCount = pasteboard.changeCount
        guard lastProcessedChangeCount != changeCount else {
            return .alreadyProcessed
        }

        guard pasteboard.hasStrings else {
            markProcessed(changeCount)
            return .noText
        }

        guard let text = pasteboard.string else {
            markProcessed(changeCount)
            return .noText
        }

        guard !text.isEmpty else {
            markProcessed(changeCount)
            return .emptyText
        }

        let wasStored = store.add(text: text, source: .systemPasteboardImport)
        markProcessed(changeCount)
        return wasStored ? .stored : .duplicate
    }

    func markProcessed(_ pasteboard: ClipboardReadablePasteboard) {
        markProcessed(pasteboard.changeCount)
    }

    private var lastProcessedChangeCount: Int? {
        defaults.object(forKey: Constants.lastProcessedChangeCountKey) as? Int
    }

    private func markProcessed(_ changeCount: Int) {
        defaults.set(changeCount, forKey: Constants.lastProcessedChangeCountKey)
    }
}

extension String {
    func hasSameUTF8Bytes(as other: String) -> Bool {
        Array(utf8) == Array(other.utf8)
    }
}
