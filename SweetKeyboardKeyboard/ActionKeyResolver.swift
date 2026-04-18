import UIKit

enum ActionKeyType: String, Codable {
    case `default`
    case go
    case google
    case join
    case next
    case route
    case search
    case send
    case yahoo
    case done
    case emergencyCall
    case `continue`
    case unknown
}

enum ActionKeyDisplayMode: String, Codable {
    case icon
    case text
}

struct ActionKeyModel: Equatable {
    let actionType: ActionKeyType
    let displayMode: ActionKeyDisplayMode
    let symbolName: String?
    let assetName: String?
    let fallbackTitle: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let performsPrimaryAction: Bool
    let debugDescription: String
    let minimumWidthMultiplier: CGFloat
}

struct ActionKeyInputContext {
    let returnKeyType: UIReturnKeyType?
    let keyboardType: UIKeyboardType?
    let textContentType: String?
    let enablesReturnKeyAutomatically: Bool?
    let hasText: Bool
    let hasDocumentText: Bool
    let hasSelection: Bool
    let documentContextContainsLineBreaks: Bool
    let traitsAvailable: Bool

    init(proxy: any UITextDocumentProxy) {
        let traits: any UITextInputTraits = proxy
        let beforeInput = proxy.documentContextBeforeInput ?? ""
        let afterInput = proxy.documentContextAfterInput ?? ""
        let resolvedTextContentType = traits.textContentType ?? nil

        returnKeyType = traits.returnKeyType
        keyboardType = traits.keyboardType
        textContentType = resolvedTextContentType.map { String(describing: $0) }
        enablesReturnKeyAutomatically = traits.enablesReturnKeyAutomatically
        let hasSelection = !(proxy.selectedText?.isEmpty ?? true)
        let hasDocumentText = !beforeInput.isEmpty || !afterInput.isEmpty
        self.hasSelection = hasSelection
        self.hasDocumentText = hasDocumentText
        hasText = proxy.hasText || hasSelection || hasDocumentText
        documentContextContainsLineBreaks = beforeInput.contains("\n") || afterInput.contains("\n")
        traitsAvailable = true
    }
}

struct ActionKeyResolver {
    func resolve(for context: ActionKeyInputContext) -> ActionKeyModel {
        let actionType = resolveActionType(for: context)

        switch actionType {
        case .default:
            return ActionKeyModel(
                actionType: .default,
                displayMode: .icon,
                symbolName: ActionKeySymbol.defaultReturn,
                assetName: nil,
                fallbackTitle: "Return",
                accessibilityLabel: "Return",
                accessibilityHint: "Inserts a line break or triggers the host field’s default return action.",
                performsPrimaryAction: true,
                debugDescription: debugDescription(for: .default, context: context),
                minimumWidthMultiplier: 2.0
            )
        case .search:
            return ActionKeyModel(
                actionType: .search,
                displayMode: .icon,
                symbolName: "magnifyingglass",
                assetName: nil,
                fallbackTitle: "Search",
                accessibilityLabel: "Search",
                accessibilityHint: "Triggers the host field’s search return action.",
                performsPrimaryAction: true,
                debugDescription: debugDescription(for: .search, context: context),
                minimumWidthMultiplier: 2.0
            )
        case .go:
            return ActionKeyModel(
                actionType: .go,
                displayMode: .icon,
                symbolName: "arrow.right",
                assetName: nil,
                fallbackTitle: "Go",
                accessibilityLabel: "Go",
                accessibilityHint: "Triggers the host field’s Go return action.",
                performsPrimaryAction: true,
                debugDescription: debugDescription(for: .go, context: context),
                minimumWidthMultiplier: 2.0
            )
        case .google:
            return makeTextModel(type: .google, title: "Google", accessibilityHint: "Triggers the host field’s Google return action.", context: context, minimumWidthMultiplier: 2.4)
        case .join:
            return makeTextModel(type: .join, title: "Join", accessibilityHint: "Triggers the host field’s Join return action.", context: context)
        case .next:
            return makeTextModel(type: .next, title: "Next", accessibilityHint: "Moves to the next field when the host app supports it.", context: context)
        case .route:
            return makeTextModel(type: .route, title: "Route", accessibilityHint: "Triggers the host field’s Route return action.", context: context)
        case .send:
            return makeTextModel(type: .send, title: "Send", accessibilityHint: "Triggers the host field’s Send return action.", context: context)
        case .yahoo:
            return makeTextModel(type: .yahoo, title: "Yahoo", accessibilityHint: "Triggers the host field’s Yahoo return action.", context: context, minimumWidthMultiplier: 2.3)
        case .done:
            return makeTextModel(type: .done, title: "Done", accessibilityHint: "Triggers the host field’s Done return action.", context: context)
        case .emergencyCall:
            return makeTextModel(type: .emergencyCall, title: "Emergency", accessibilityLabel: "Emergency Call", accessibilityHint: "Triggers the host field’s Emergency Call return action.", context: context, minimumWidthMultiplier: 3.1)
        case .continue:
            return makeTextModel(type: .continue, title: "Continue", accessibilityHint: "Triggers the host field’s Continue return action.", context: context, minimumWidthMultiplier: 2.8)
        case .unknown:
            return makeTextModel(type: .unknown, title: "Return", accessibilityLabel: "Return", accessibilityHint: "Triggers the host field’s default return action.", context: context)
        }
    }

    func isEnabled(for model: ActionKeyModel, context: ActionKeyInputContext) -> Bool {
        _ = model
        _ = context
        return true
    }

    private func resolveActionType(for context: ActionKeyInputContext) -> ActionKeyType {
        guard let returnKeyType = context.returnKeyType else {
            return .default
        }

        switch returnKeyType {
        case .default:
            return .default
        case .go:
            return .go
        case .google:
            return .google
        case .join:
            return .join
        case .next:
            return .next
        case .route:
            return .route
        case .search:
            return .search
        case .send:
            return .send
        case .yahoo:
            return .yahoo
        case .done:
            return .done
        case .emergencyCall:
            return .emergencyCall
        case .continue:
            return .continue
        @unknown default:
            return .unknown
        }
    }

    private func makeTextModel(
        type: ActionKeyType,
        title: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String,
        context: ActionKeyInputContext,
        minimumWidthMultiplier: CGFloat = 2.0
    ) -> ActionKeyModel {
        ActionKeyModel(
            actionType: type,
            displayMode: .text,
            symbolName: nil,
            assetName: nil,
            fallbackTitle: title,
            accessibilityLabel: accessibilityLabel ?? title,
            accessibilityHint: accessibilityHint,
            performsPrimaryAction: true,
            debugDescription: debugDescription(for: type, context: context),
            minimumWidthMultiplier: minimumWidthMultiplier
        )
    }

    private func debugDescription(for actionType: ActionKeyType, context: ActionKeyInputContext) -> String {
        if let returnKeyType = context.returnKeyType {
            return "Resolved \(actionType.rawValue) from returnKeyType=\(returnKeyType.debugName)"
        }

        if context.traitsAvailable {
            return "Fell back to default because returnKeyType was unavailable on the proxy."
        }

        return "Fell back to default because the host app did not expose text input traits to the custom keyboard."
    }
}

private enum ActionKeySymbol {
    static let defaultReturn = "return.left"
}

extension UIReturnKeyType {
    var debugName: String {
        switch self {
        case .default:
            return "default"
        case .go:
            return "go"
        case .google:
            return "google"
        case .join:
            return "join"
        case .next:
            return "next"
        case .route:
            return "route"
        case .search:
            return "search"
        case .send:
            return "send"
        case .yahoo:
            return "yahoo"
        case .done:
            return "done"
        case .emergencyCall:
            return "emergencyCall"
        case .continue:
            return "continue"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }
}

extension UIKeyboardType {
    var debugName: String {
        switch self {
        case .default:
            return "default"
        case .asciiCapable:
            return "asciiCapable"
        case .numbersAndPunctuation:
            return "numbersAndPunctuation"
        case .URL:
            return "URL"
        case .numberPad:
            return "numberPad"
        case .phonePad:
            return "phonePad"
        case .namePhonePad:
            return "namePhonePad"
        case .emailAddress:
            return "emailAddress"
        case .decimalPad:
            return "decimalPad"
        case .twitter:
            return "twitter"
        case .webSearch:
            return "webSearch"
        case .asciiCapableNumberPad:
            return "asciiCapableNumberPad"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }
}
