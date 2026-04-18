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
    static let keyCornerRadius: CGFloat = 10
    static let utilityCornerRadius: CGFloat = 9
    static let feedbackCornerRadius: CGFloat = 11

    static let iconButtonWidth: CGFloat = 34
    static let iconPointSize: CGFloat = 16
    static let actionSymbolPointSize: CGFloat = 19

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

    static var panelBackground: UIColor {
        keyBackground
    }

    static var panelItemBackground: UIColor {
        keyBackground
    }

    static var borderColor: UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.14)
            }

            return UIColor.black.withAlphaComponent(0.12)
        }
    }

    static var keyShadowColor: UIColor {
        UIColor.black.withAlphaComponent(0.18)
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

    static func applyChrome(to button: UIButton, role: KeyboardButtonRole, isActive: Bool = false, cornerRadius: CGFloat) {
        button.backgroundColor = background(for: role, isActive: isActive)
        button.setTitleColor(keyLabelColor, for: .normal)
        button.tintColor = keyLabelColor
        button.layer.cornerRadius = cornerRadius
        button.layer.cornerCurve = .continuous
        button.layer.shadowColor = keyShadowColor.cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
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
