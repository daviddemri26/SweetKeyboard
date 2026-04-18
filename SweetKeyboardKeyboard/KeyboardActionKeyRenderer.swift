import UIKit

enum KeyboardActionKeyRenderer {
    static func apply(
        model: ActionKeyModel,
        isEnabled: Bool,
        to button: UIButton,
        widthConstraint: NSLayoutConstraint?
    ) {
        let preferredSymbol = model.symbolName.flatMap(primaryActionSymbol(named:))
        let useIcon = model.displayMode == .icon && preferredSymbol != nil
        let isGoAction = model.actionType == .go

        button.setTitle(nil, for: .normal)
        button.setTitle(nil, for: .highlighted)
        button.setImage(nil, for: .normal)
        button.setImage(nil, for: .highlighted)

        if useIcon, let preferredSymbol {
            let normalConfiguration = UIImage.SymbolConfiguration(
                pointSize: KeyboardMetrics.actionSymbolPointSize,
                weight: .medium
            )
            let highlightedConfiguration = UIImage.SymbolConfiguration(
                pointSize: KeyboardMetrics.actionSymbolPointSize,
                weight: .semibold
            )

            if let pressableButton = button as? KeyboardPressableButton {
                pressableButton.setSymbolConfigurations(
                    normal: normalConfiguration,
                    highlighted: highlightedConfiguration
                )
                pressableButton.setSymbolImage(preferredSymbol)
            } else {
                button.setPreferredSymbolConfiguration(normalConfiguration, forImageIn: .normal)
                let templatedImage = preferredSymbol.withRenderingMode(.alwaysTemplate)
                button.setImage(templatedImage, for: .normal)
                button.setImage(templatedImage, for: .highlighted)
            }
        } else {
            button.setTitle(model.fallbackTitle, for: .normal)
        }

        button.isEnabled = isEnabled
        KeyboardTheme.applyChrome(
            to: button,
            role: .primaryAction,
            cornerRadius: KeyboardMetrics.keyCornerRadius
        )

        if let pressableButton = button as? KeyboardPressableButton {
            let normalBackground = isGoAction ? goActionBackgroundColor : KeyboardTheme.background(for: .primaryAction)
            let highlightedBackground = KeyboardTheme.pressedBackground(for: .primaryAction)
            pressableButton.setBackgroundColors(normal: normalBackground, highlighted: highlightedBackground)
            pressableButton.setForegroundColors(
                normal: isGoAction ? .white : KeyboardTheme.keyLabelColor,
                highlighted: isGoAction ? KeyboardTheme.goActionPressedForegroundColor : KeyboardTheme.keyLabelColor
            )
        } else {
            button.setTitleColor(isGoAction ? .white : KeyboardTheme.keyLabelColor, for: .normal)
            button.setTitleColor(
                isGoAction ? KeyboardTheme.goActionPressedForegroundColor : KeyboardTheme.keyLabelColor,
                for: .highlighted
            )
            button.tintColor = isGoAction ? .white : KeyboardTheme.keyLabelColor
            button.backgroundColor = isGoAction ? goActionBackgroundColor : button.backgroundColor
        }

        if let pressableButton = button as? KeyboardPressableButton {
            pressableButton.setBorder(
                width: KeyboardMetrics.functionKeyBorderWidth,
                colorProvider: { _ in KeyboardTheme.functionKeyBorderColor }
            )
        } else {
            button.layer.borderWidth = KeyboardMetrics.functionKeyBorderWidth
            button.layer.borderColor = KeyboardTheme.functionKeyBorderColor.resolvedColor(with: button.traitCollection).cgColor
        }
        button.accessibilityLabel = model.accessibilityLabel
        button.accessibilityHint = model.accessibilityHint
        button.accessibilityIdentifier = "action-key-\(model.actionType.rawValue)"
        widthConstraint?.constant = KeyboardMetrics.keyUnitWidth * model.minimumWidthUnits
    }

    private static func primaryActionSymbol(named name: String) -> UIImage? {
        if let image = UIImage(systemName: name) {
            return image
        }

        if name == "return.left" {
            return UIImage(systemName: "arrow.turn.down.left")
        }

        return nil
    }

    private static var goActionBackgroundColor: UIColor {
        UIColor(red: 52 / 255, green: 120 / 255, blue: 245 / 255, alpha: 1)
    }
}
