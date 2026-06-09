import Symbols
import UIKit

enum KeyboardMetrics {
    static let visualHorizontalInset: CGFloat = 4
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
    static let keyboardRowSpacing: CGFloat = 4
    static let keyboardKeySpacing: CGFloat = 4
    static var keyboardVisualRowSpacing: CGFloat { keyboardRowSpacing }
    static var keyboardVisualKeySpacing: CGFloat { keyboardKeySpacing }
    static var keyboardTouchVerticalInset: CGFloat { keyboardVisualRowSpacing / 2 }
    static var keyboardTouchHorizontalInset: CGFloat { keyboardVisualKeySpacing / 2 }

    static let keyUnitWidth: CGFloat = 28
    static let keyCornerRadius: CGFloat = 7
    static let utilityCornerRadius: CGFloat = 9
    static let nativeClipboardButtonCornerRadius: CGFloat = 9
    static let actionBarButtonCornerRadius: CGFloat = 17

    static let iconButtonWidth: CGFloat = 34
    static let iconPointSize: CGFloat = 16
    static let actionSymbolPointSize: CGFloat = 20
    static let cursorSymbolPointSize: CGFloat = 14
    static let functionKeyBorderWidth: CGFloat = 0.8

    static let characterKeyFontSize: CGFloat = 25.2
    static let systemKeyFontSize: CGFloat = 18
    static let backspaceKeyFontSize: CGFloat = 21.6
    static let primaryActionFontSize: CGFloat = 18
    static let utilityButtonFontSize: CGFloat = 17

    static let settingsPanelCornerRadius: CGFloat = 14

    static func keyboardBottomInset(for safeAreaInsets: UIEdgeInsets) -> CGFloat {
        max(minimumKeyboardBottomInset, safeAreaInsets.bottom)
    }

    static func keyboardContainerHeight(bottomInset: CGFloat) -> CGFloat {
        keyboardTopPadding +
        (keyboardRowHeight * 5) +
        (keyboardVisualRowSpacing * 4) +
        bottomInset
    }

    static func totalKeyboardHeight(bottomInset: CGFloat, showsUtilityRow: Bool) -> CGFloat {
        let utilityHeight = showsUtilityRow ? (utilityRowHeight + utilityRowSpacing) : 0
        return outerTopPadding +
        utilityHeight +
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

    static var secondaryLabelColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0xC7C7CC)
            }

            return UIColor(hex: 0x5F6673)
        }
    }

    static var functionKeyBorderColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x66666A, alpha: 0.88)
            }

            return UIColor(hex: 0xC8CDD6)
        }
    }

    static var activeClipboardBorderColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0xA6ABB5, alpha: 0.96)
            }

            return UIColor(hex: 0x7B8493, alpha: 0.98)
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

    static var settingsScreenBackground: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x111214)
            }

            return UIColor(hex: 0xF2F2F7)
        }
    }

    static var settingsGroupBackground: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x1C1C1E)
            }

            return UIColor(hex: 0xFFFFFF)
        }
    }

    static var settingsSeparatorColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x38383A)
            }

            return UIColor(hex: 0xD1D1D6)
        }
    }

    static var settingsAccentColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x5EA0FF)
            }

            return UIColor(hex: 0x007AFF)
        }
    }

    static var settingsDonePressedBackground: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: 0x2C2C2E, alpha: 0.9)
            }

            return UIColor(hex: 0xDCE9FF, alpha: 0.95)
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
            return UIColor { traits in
                if isActive {
                    if traits.userInterfaceStyle == .dark {
                        return UIColor(hex: 0x6B6B6F)
                    }

                    return UIColor(hex: 0xB9BDC6)
                }

                if traits.userInterfaceStyle == .dark {
                    return UIColor(hex: 0x7F7F81)
                }

                return UIColor(hex: 0xC5C4C9)
            }
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

        if let pressableButton = button as? KeyboardPressableButton {
            pressableButton.setKeyDepthChromeEnabled(role != .utility)
        }
    }
}

final class KeyboardPressableButton: UIButton {
    private let depthLayer = CAShapeLayer()
    private let faceLayer = CAShapeLayer()
    private var normalBackgroundColor: UIColor?
    private var highlightedBackgroundColor: UIColor?
    private var normalTitleFont: UIFont?
    private var highlightedTitleFont: UIFont?
    private var normalForegroundColor: UIColor?
    private var highlightedForegroundColor: UIColor?
    private var borderColorProvider: ((UITraitCollection) -> UIColor)?
    private var usesKeyDepthChrome = false

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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBorderAppearance()
        updateDepthChromeAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateDepthChromePaths()
        keepContentAboveDepthChrome()
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
        keepContentAboveDepthChrome()
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
        keepContentAboveDepthChrome()
    }

    func setBorder(width: CGFloat, colorProvider: ((UITraitCollection) -> UIColor)? = nil) {
        layer.borderWidth = width
        borderColorProvider = colorProvider
        updateBorderAppearance()
    }

    func setKeyDepthChromeEnabled(_ isEnabled: Bool) {
        usesKeyDepthChrome = isEnabled

        if isEnabled {
            if depthLayer.superlayer == nil {
                layer.insertSublayer(depthLayer, at: 0)
            }
            if faceLayer.superlayer == nil {
                layer.insertSublayer(faceLayer, above: depthLayer)
            }
        } else {
            depthLayer.removeFromSuperlayer()
            faceLayer.removeFromSuperlayer()
        }

        updateDepthChromeAppearance()
        updateDepthChromePaths()
        keepContentAboveDepthChrome()
    }

    private func updatePressedAppearance() {
        backgroundColor = usesKeyDepthChrome ? .clear : currentBackgroundColor
        updateDepthChromeAppearance()
        updateDepthChromePaths()
        keepContentAboveDepthChrome()

        if let normalForegroundColor {
            tintColor = (isHighlighted && isEnabled) ? highlightedForegroundColor ?? normalForegroundColor : normalForegroundColor
            imageView?.tintColor = tintColor
        }

        guard let normalTitleFont else {
            return
        }

        titleLabel?.font = (isHighlighted && isEnabled) ? highlightedTitleFont ?? normalTitleFont : normalTitleFont
    }

    private var currentBackgroundColor: UIColor? {
        (isHighlighted && isEnabled) ? highlightedBackgroundColor ?? normalBackgroundColor : normalBackgroundColor
    }

    private func updateBorderAppearance() {
        guard layer.borderWidth > 0, let borderColorProvider else {
            layer.borderColor = UIColor.clear.cgColor
            return
        }

        layer.borderColor = borderColorProvider(traitCollection).cgColor
    }

    private func updateDepthChromeAppearance() {
        guard usesKeyDepthChrome else {
            backgroundColor = currentBackgroundColor
            layer.shadowColor = UIColor.clear.cgColor
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
            layer.shadowPath = nil
            depthLayer.isHidden = true
            faceLayer.isHidden = true
            return
        }

        let isPressed = isHighlighted && isEnabled
        let isDark = traitCollection.userInterfaceStyle == .dark

        backgroundColor = .clear
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = isPressed ? (isDark ? 0.08 : 0.03) : (isDark ? 0.18 : 0.08)
        layer.shadowRadius = isPressed ? 0.25 : 0.65
        layer.shadowOffset = CGSize(width: 0, height: isPressed ? 0.3 : 0.7)

        depthLayer.isHidden = false
        faceLayer.isHidden = false
        depthLayer.fillColor = UIColor.black.withAlphaComponent(
            isPressed ? (isDark ? 0.26 : 0.16) : (isDark ? 0.46 : 0.34)
        ).cgColor
        if let currentBackgroundColor {
            faceLayer.fillColor = currentBackgroundColor
                .resolvedColor(with: traitCollection)
                .cgColor
        } else {
            faceLayer.fillColor = UIColor.clear.cgColor
        }
    }

    private func updateDepthChromePaths() {
        guard usesKeyDepthChrome, bounds.width > 0, bounds.height > 0 else {
            return
        }

        let facePath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
        let depthOffset: CGFloat = (isHighlighted && isEnabled) ? 0.45 : 1.55
        let depthPath = UIBezierPath(
            roundedRect: bounds.offsetBy(dx: 0, dy: depthOffset),
            cornerRadius: layer.cornerRadius
        ).cgPath

        depthLayer.frame = bounds
        faceLayer.frame = bounds
        depthLayer.path = depthPath
        faceLayer.path = facePath
        layer.shadowPath = facePath
    }

    private func keepContentAboveDepthChrome() {
        if let imageView {
            bringSubviewToFront(imageView)
        }

        if let titleLabel {
            bringSubviewToFront(titleLabel)
        }
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
