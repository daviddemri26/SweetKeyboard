import UIKit

enum KeyboardMetrics {
    static let outerHorizontalPadding: CGFloat = 6
    static let outerTopPadding: CGFloat = 4
    static let outerBottomPadding: CGFloat = 0

    static let utilityRowHeight: CGFloat = 34
    static let utilityRowSpacing: CGFloat = 6
    static let utilityButtonHorizontalPadding: CGFloat = 12
    static let utilityRowButtonSpacing: CGFloat = 6
    static let utilityGroupSpacing: CGFloat = 6

    static let keyboardTopPadding: CGFloat = 4
    static let minimumKeyboardBottomInset: CGFloat = 4
    static let keyboardRowHeight: CGFloat = 42
    static let keyboardRowSpacing: CGFloat = 6
    static let keyboardKeySpacing: CGFloat = 6

    static let keyUnitWidth: CGFloat = 28
    static let keyCornerRadius: CGFloat = 9
    static let utilityCornerRadius: CGFloat = 9
    static let feedbackCornerRadius: CGFloat = 11

    static let iconButtonWidth: CGFloat = 34
    static let iconPointSize: CGFloat = 16
    static let actionSymbolPointSize: CGFloat = 20

    static let characterKeyFontSize: CGFloat = 25.2
    static let systemKeyFontSize: CGFloat = 18
    static let backspaceKeyFontSize: CGFloat = 21.6
    static let primaryActionFontSize: CGFloat = 18
    static let utilityButtonFontSize: CGFloat = 17

    static let settingsPanelCornerRadius: CGFloat = 14
    static let panelItemCornerRadius: CGFloat = 12

    static let feedbackHeight: CGFloat = 28
    static let feedbackBottomInset: CGFloat = 14

    static func keyboardBottomInset(for safeAreaInsets: UIEdgeInsets) -> CGFloat {
        max(minimumKeyboardBottomInset, safeAreaInsets.bottom)
    }

    static func keyboardContainerHeight(bottomInset: CGFloat) -> CGFloat {
        keyboardTopPadding +
        (keyboardRowHeight * 5) +
        (keyboardRowSpacing * 4) +
        bottomInset
    }

    static func totalKeyboardHeight(bottomInset: CGFloat) -> CGFloat {
        outerTopPadding +
        utilityRowHeight +
        utilityRowSpacing +
        keyboardContainerHeight(bottomInset: bottomInset) +
        outerBottomPadding
    }
}

enum KeyboardButtonRole {
    case character
    case system
    case primaryAction
    case utility
}

enum KeyboardTheme {
    static var keyboardBackground: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x171717)
            }

            return UIColor(hex: 0xE3E4E8)
        }
    }

    static var keyBackground: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x3D3D3D)
            }

            return UIColor(hex: 0xFFFFFF)
        }
    }

    static var keyLabelColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0xFFFFFF)
            }

            return UIColor(hex: 0x000000)
        }
    }

    static var goActionPressedForegroundColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0xFFFFFF)
            }

            return UIColor(hex: 0x000000)
        }
    }

    static var panelBackground: UIColor {
        keyBackground
    }

    static var panelItemBackground: UIColor {
        keyBackground
    }

    static var feedbackBackground: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x3A3A3C, alpha: 0.94)
            }

            return UIColor(hex: 0xF7F8FA, alpha: 0.96)
        }
    }

    static func background(for role: KeyboardButtonRole, isActive: Bool = false) -> UIColor {
        switch role {
        case .character, .system, .primaryAction:
            return keyBackground
        case .utility:
            return UIColor { traits in
                if isActive {
                    if traits.userInterfaceStyle == .dark {
                        return UIColor(hex: 0x4A4A4A)
                    }

                    return UIColor(hex: 0xD2D4DA)
                }

                if traits.userInterfaceStyle == .dark {
                    return UIColor(hex: 0x3D3D3D)
                }

                return UIColor(hex: 0xFFFFFF)
            }
        }
    }

    static func pressedBackground(for role: KeyboardButtonRole, isActive: Bool = false) -> UIColor {
        switch role {
        case .character, .system, .primaryAction:
            return UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(hex: 0x7F7F81)
                }

                return UIColor(hex: 0xC5C4C9)
            }
        case .utility:
            return background(for: role, isActive: isActive)
        }
    }

    static func applyChrome(to button: UIButton, role: KeyboardButtonRole, isActive: Bool = false, cornerRadius: CGFloat) {
        let normalBackground = background(for: role, isActive: isActive)
        let highlightedBackground = pressedBackground(for: role, isActive: isActive)

        if let pressableButton = button as? KeyboardPressableButton {
            pressableButton.setBackgroundColors(normal: normalBackground, highlighted: highlightedBackground)
        } else {
            button.backgroundColor = normalBackground
        }

        button.setTitleColor(keyLabelColor, for: .normal)
        button.setTitleColor(keyLabelColor, for: .highlighted)
        button.setTitleColor(keyLabelColor, for: .selected)
        button.setTitleColor(keyLabelColor, for: .disabled)
        button.tintColor = keyLabelColor
        button.layer.cornerRadius = cornerRadius
        button.layer.cornerCurve = .continuous
        button.layer.shadowColor = UIColor.clear.cgColor
        button.layer.shadowOpacity = 0
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = .zero
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
    }
}

final class KeyboardPressableButton: UIButton {
    private var normalBackgroundColor: UIColor?
    private var highlightedBackgroundColor: UIColor?
    private var normalTitleFont: UIFont?
    private var highlightedTitleFont: UIFont?
    private var normalForegroundColor: UIColor?
    private var highlightedForegroundColor: UIColor?

    override var isHighlighted: Bool {
        didSet {
            updatePressedAppearance()
        }
    }

    override var isEnabled: Bool {
        didSet {
            updatePressedAppearance()
        }
    }

    func setBackgroundColors(normal: UIColor, highlighted: UIColor) {
        normalBackgroundColor = normal
        highlightedBackgroundColor = highlighted
        updatePressedAppearance()
    }

    func setTitleFonts(normal: UIFont, highlighted: UIFont? = nil) {
        normalTitleFont = normal
        highlightedTitleFont = highlighted ?? UIFont.boldSystemFont(ofSize: normal.pointSize)
        updatePressedAppearance()
    }

    func setForegroundColors(normal: UIColor, highlighted: UIColor? = nil) {
        let highlightedColor = highlighted ?? normal
        normalForegroundColor = normal
        highlightedForegroundColor = highlightedColor
        setTitleColor(normal, for: .normal)
        setTitleColor(highlightedColor, for: .highlighted)
        tintColor = isHighlighted && isEnabled ? highlightedColor : normal
        imageView?.tintColor = tintColor
    }

    func setSymbolConfigurations(normal: UIImage.SymbolConfiguration, highlighted: UIImage.SymbolConfiguration? = nil) {
        let highlightedConfiguration = highlighted ?? normal
        setPreferredSymbolConfiguration(normal, forImageIn: .normal)
        setPreferredSymbolConfiguration(highlightedConfiguration, forImageIn: .highlighted)
    }

    func setSymbolImage(_ image: UIImage?) {
        let templatedImage = image?.withRenderingMode(.alwaysTemplate)
        setImage(templatedImage, for: .normal)
        setImage(templatedImage, for: .highlighted)
    }

    private func updatePressedAppearance() {
        backgroundColor = (isHighlighted && isEnabled) ? highlightedBackgroundColor ?? normalBackgroundColor : normalBackgroundColor

        if let normalForegroundColor {
            tintColor = (isHighlighted && isEnabled) ? highlightedForegroundColor ?? normalForegroundColor : normalForegroundColor
            imageView?.tintColor = tintColor
        }

        guard let normalTitleFont else {
            return
        }

        titleLabel?.font = (isHighlighted && isEnabled) ? highlightedTitleFont ?? normalTitleFont : normalTitleFont
    }
}

private extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
