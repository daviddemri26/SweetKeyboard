import UIKit

enum AutoCapitalizationDecision: Equatable {
    case off
    case singleLetter
    case persistent
}

struct AutoCapitalizationContext: Equatable {
    let isEnabled: Bool
    let autocapitalizationType: UITextAutocapitalizationType?
    let keyboardType: UIKeyboardType?
    let textContentType: String?
    let documentContextBeforeInput: String
    let documentContextAfterInput: String
    let hasSelection: Bool
}

struct AutoCapitalizationResolver {
    func resolve(for context: AutoCapitalizationContext) -> AutoCapitalizationDecision {
        guard context.isEnabled, !context.hasSelection else {
            return .off
        }

        if shouldForceAutoCapitalizationOff(for: context) {
            return .off
        }

        switch context.autocapitalizationType ?? .sentences {
        case .none:
            return .off
        case .allCharacters:
            return .persistent
        case .words:
            return resolveWordsDecision(beforeInput: context.documentContextBeforeInput)
        case .sentences:
            return resolveSentencesDecision(beforeInput: context.documentContextBeforeInput)
        @unknown default:
            return resolveSentencesDecision(beforeInput: context.documentContextBeforeInput)
        }
    }

    private func shouldForceAutoCapitalizationOff(for context: AutoCapitalizationContext) -> Bool {
        if context.autocapitalizationType == UITextAutocapitalizationType.none {
            return true
        }

        if context.keyboardType == .emailAddress || context.textContentType == AutoCapitalizationTextContentType.emailAddress {
            return true
        }

        if context.keyboardType == .URL || context.textContentType == AutoCapitalizationTextContentType.url {
            return true
        }

        return context.textContentType == AutoCapitalizationTextContentType.username
    }

    private func resolveWordsDecision(beforeInput: String) -> AutoCapitalizationDecision {
        if beforeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .singleLetter
        }

        guard let lastScalar = beforeInput.unicodeScalars.last else {
            return .singleLetter
        }

        return CharacterSet.whitespacesAndNewlines.contains(lastScalar) ? .singleLetter : .off
    }

    private func resolveSentencesDecision(beforeInput: String) -> AutoCapitalizationDecision {
        if beforeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .singleLetter
        }

        var skippedTrailingSpaces = false

        for scalar in beforeInput.unicodeScalars.reversed() {
            if CharacterSet.whitespaces.contains(scalar) {
                skippedTrailingSpaces = true
                continue
            }

            if CharacterSet.newlines.contains(scalar) {
                return .singleLetter
            }

            return sentenceTerminators.contains(scalar) && skippedTrailingSpaces ? .singleLetter : .off
        }

        return .singleLetter
    }

    private var sentenceTerminators: CharacterSet {
        CharacterSet(charactersIn: ".!?")
    }
}

private enum AutoCapitalizationTextContentType {
    static let emailAddress = String(describing: UITextContentType.emailAddress)
    static let url = String(describing: UITextContentType.URL)
    static let username = String(describing: UITextContentType.username)
}
