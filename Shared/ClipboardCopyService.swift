import Foundation

protocol ClipboardTextPasteboard: AnyObject {
    var string: String? { get set }
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

extension String {
    func hasSameUTF8Bytes(as other: String) -> Bool {
        Array(utf8) == Array(other.utf8)
    }
}
