import UIKit

final class KeyboardActionBarView: UIView {
    enum Action {
        case copy
        case importClipboard
        case clipboard
        case settings
        case hideKeyboard
    }

    var onAction: ((Action) -> Void)?

    private let settingsButton = KeyboardActionBarView.makeIconButton(symbolName: "gearshape")
    private let hideKeyboardButton = KeyboardActionBarView.makeIconButton(symbolName: "chevron.down.2")
    private let importClipboardButton = KeyboardActionBarView.makeIconButton(symbolName: "square.and.arrow.down")
    private let copyButton = KeyboardActionBarView.makeIconButton(symbolName: "doc.on.doc")
    private let clipboardButton = KeyboardActionBarView.makeIconButton(symbolNames: ["list.clipboard", "clipboard"])

    private var isClipboardActive = false
    private var isSettingsActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        observeTraitChanges()
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setClipboardActive(_ active: Bool) {
        isClipboardActive = active
        applyTheme()
    }

    func setSettingsActive(_ active: Bool) {
        isSettingsActive = active
        applyTheme()
    }

    func setClipboardImportAvailable(_ available: Bool) {
        importClipboardButton.isHidden = !available
    }

    private func observeTraitChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) {
            (self: Self, _: UITraitCollection) in
            self.applyTheme()
        }
    }

    private func setup() {
        backgroundColor = .clear

        let rightStack = UIStackView(arrangedSubviews: [importClipboardButton, copyButton, clipboardButton])
        rightStack.axis = .horizontal
        rightStack.alignment = .fill
        rightStack.spacing = KeyboardMetrics.utilityRowButtonSpacing

        let leftStack = UIStackView(arrangedSubviews: [settingsButton, hideKeyboardButton])
        leftStack.axis = .horizontal
        leftStack.alignment = .fill
        leftStack.spacing = KeyboardMetrics.utilityRowButtonSpacing

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [leftStack, spacer, rightStack])
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = KeyboardMetrics.utilityGroupSpacing

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: KeyboardMetrics.utilityRowHeight)
        ])

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        importClipboardButton.addTarget(self, action: #selector(importClipboardTapped), for: .touchUpInside)
        clipboardButton.addTarget(self, action: #selector(clipboardTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        hideKeyboardButton.addTarget(self, action: #selector(hideKeyboardTapped), for: .touchUpInside)

        copyButton.accessibilityLabel = "Copy"
        copyButton.accessibilityHint = "Copies selected text into SweetKeyboard history."
        importClipboardButton.isHidden = true
        importClipboardButton.accessibilityLabel = "Import clipboard"
        importClipboardButton.accessibilityHint = "Imports the current iOS clipboard text into SweetKeyboard history."
        clipboardButton.accessibilityLabel = "Clipboard"
        clipboardButton.accessibilityHint = "Shows SweetKeyboard clipboard history."
        settingsButton.accessibilityLabel = "Settings"
        settingsButton.accessibilityHint = "Shows SweetKeyboard settings."
        hideKeyboardButton.accessibilityLabel = "Hide keyboard"
        hideKeyboardButton.accessibilityHint = "Dismisses the keyboard from the screen."
    }

    private func applyTheme() {
        KeyboardTheme.applyChrome(
            to: copyButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.actionBarButtonCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: clipboardButton,
            role: .utility,
            isActive: isClipboardActive,
            cornerRadius: KeyboardMetrics.actionBarButtonCornerRadius
        )
        if isClipboardActive, let pressableButton = clipboardButton as? KeyboardPressableButton {
            pressableButton.setBorder(
                width: KeyboardMetrics.functionKeyBorderWidth,
                colorProvider: { _ in KeyboardTheme.functionKeyBorderColor }
            )
        }
        KeyboardTheme.applyChrome(
            to: importClipboardButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.actionBarButtonCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: settingsButton,
            role: .utility,
            isActive: isSettingsActive,
            cornerRadius: KeyboardMetrics.actionBarButtonCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: hideKeyboardButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.actionBarButtonCornerRadius
        )
    }

    private static func makeIconButton(symbolName: String) -> KeyboardPressableButton {
        makeIconButton(symbolNames: [symbolName])
    }

    private static func makeIconButton(symbolNames: [String]) -> KeyboardPressableButton {
        let button = KeyboardPressableButton(type: .custom)
        button.setSymbolConfigurations(
            normal: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .medium),
            highlighted: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .semibold)
        )
        button.setForegroundColors(
            normal: KeyboardTheme.keyLabelColor,
            highlighted: KeyboardTheme.keyLabelColor
        )
        button.setSymbolImage(symbolNames.lazy.compactMap { UIImage(systemName: $0) }.first)
        button.widthAnchor.constraint(equalToConstant: KeyboardMetrics.iconButtonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: KeyboardMetrics.utilityRowHeight).isActive = true
        return button
    }

    @objc private func copyTapped() {
        onAction?(.copy)
    }

    @objc private func importClipboardTapped() {
        onAction?(.importClipboard)
    }

    @objc private func clipboardTapped() {
        onAction?(.clipboard)
    }

    @objc private func settingsTapped() {
        onAction?(.settings)
    }

    @objc private func hideKeyboardTapped() {
        onAction?(.hideKeyboard)
    }
}
