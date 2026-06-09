import UIKit

final class KeyboardActionBarView: UIView {
    enum Action {
        case copy
        case importClipboard
        case pasteClipboard
        case importAndPasteClipboard
        case clipboard
        case clearText
        case settings
        case hideKeyboard
    }

    var onAction: ((Action) -> Void)?
    var onPressDown: (() -> Void)?

    private let settingsButton = KeyboardActionBarView.makeIconButton(symbolName: "gearshape.fill")
    private let hideKeyboardButton = KeyboardActionBarView.makeIconButton(symbolName: "chevron.down.2")
    private let importClipboardButton = KeyboardActionBarView.makeIconButton(symbolName: "square.and.arrow.down.on.square")
    private let pasteClipboardButton = KeyboardActionBarView.makeIconButton(symbolName: "square.filled.on.square")
    private let importAndPasteClipboardButton = KeyboardActionBarView.makeIconButton(
        symbolNames: ["doc.on.clipboard.fill", "doc.on.clipboard", "square.and.arrow.down.on.square"]
    )
    private let copyButton = KeyboardActionBarView.makeIconButton(symbolName: "square.on.square")
    private let clipboardButton = KeyboardActionBarView.makeIconButton(symbolName: "list.clipboard.fill")
    private let clearTextButton = KeyboardActionBarView.makeIconButton(symbolName: "eraser.line.dashed.fill")

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

    func setSystemClipboardActionsAvailable(_ available: Bool, actions: Set<SystemClipboardAction>) {
        importClipboardButton.isHidden = !(available && actions.contains(.importOnly))
        pasteClipboardButton.isHidden = !(available && actions.contains(.pasteOnly))
        importAndPasteClipboardButton.isHidden = !(available && actions.contains(.pasteAndSave))
    }

    private func observeTraitChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) {
            (self: Self, _: UITraitCollection) in
            self.applyTheme()
        }
    }

    private func setup() {
        backgroundColor = .clear

        let rightStack = UIStackView(arrangedSubviews: [
            importAndPasteClipboardButton,
            importClipboardButton,
            pasteClipboardButton,
            copyButton,
            clipboardButton
        ])
        rightStack.axis = .horizontal
        rightStack.alignment = .fill
        rightStack.spacing = KeyboardMetrics.utilityRowButtonSpacing

        let leftStack = UIStackView(arrangedSubviews: [settingsButton, hideKeyboardButton])
        leftStack.axis = .horizontal
        leftStack.alignment = .fill
        leftStack.spacing = KeyboardMetrics.utilityRowButtonSpacing

        let centerStack = UIStackView(arrangedSubviews: [clearTextButton])
        centerStack.axis = .horizontal
        centerStack.alignment = .fill
        centerStack.spacing = KeyboardMetrics.utilityRowButtonSpacing

        let layoutContainer = UIView()
        addSubview(layoutContainer)
        layoutContainer.translatesAutoresizingMaskIntoConstraints = false
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        layoutContainer.addSubview(leftStack)
        layoutContainer.addSubview(centerStack)
        layoutContainer.addSubview(rightStack)

        let centerXConstraint = centerStack.centerXAnchor.constraint(equalTo: layoutContainer.centerXAnchor)
        centerXConstraint.priority = UILayoutPriority(750)

        NSLayoutConstraint.activate([
            layoutContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KeyboardMetrics.visualHorizontalInset),
            layoutContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -KeyboardMetrics.visualHorizontalInset),
            layoutContainer.topAnchor.constraint(equalTo: topAnchor),
            layoutContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            leftStack.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor),
            leftStack.topAnchor.constraint(equalTo: layoutContainer.topAnchor),
            leftStack.bottomAnchor.constraint(equalTo: layoutContainer.bottomAnchor),

            centerXConstraint,
            centerStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: leftStack.trailingAnchor,
                constant: KeyboardMetrics.utilityGroupSpacing
            ),
            centerStack.trailingAnchor.constraint(
                lessThanOrEqualTo: rightStack.leadingAnchor,
                constant: -KeyboardMetrics.utilityGroupSpacing
            ),
            centerStack.topAnchor.constraint(equalTo: layoutContainer.topAnchor),
            centerStack.bottomAnchor.constraint(equalTo: layoutContainer.bottomAnchor),

            rightStack.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor),
            rightStack.topAnchor.constraint(equalTo: layoutContainer.topAnchor),
            rightStack.bottomAnchor.constraint(equalTo: layoutContainer.bottomAnchor),
            heightAnchor.constraint(equalToConstant: KeyboardMetrics.utilityRowHeight)
        ])

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        importClipboardButton.addTarget(self, action: #selector(importClipboardTapped), for: .touchUpInside)
        pasteClipboardButton.addTarget(self, action: #selector(pasteClipboardTapped), for: .touchUpInside)
        importAndPasteClipboardButton.addTarget(self, action: #selector(importAndPasteClipboardTapped), for: .touchUpInside)
        clipboardButton.addTarget(self, action: #selector(clipboardTapped), for: .touchUpInside)
        clearTextButton.addTarget(self, action: #selector(clearTextTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        hideKeyboardButton.addTarget(self, action: #selector(hideKeyboardTapped), for: .touchUpInside)
        [
            copyButton,
            importClipboardButton,
            pasteClipboardButton,
            importAndPasteClipboardButton,
            clipboardButton,
            clearTextButton,
            settingsButton,
            hideKeyboardButton
        ].forEach {
            $0.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        }

        copyButton.accessibilityLabel = "Copy"
        copyButton.accessibilityHint = "Copies selected text into SweetKeyboard Clipboard."
        importClipboardButton.isHidden = true
        pasteClipboardButton.isHidden = true
        importAndPasteClipboardButton.isHidden = true
        importClipboardButton.accessibilityLabel = "Just Import from native iPhone Clipboard"
        importClipboardButton.accessibilityHint = "Saves the current native iPhone Clipboard text into SweetKeyboard Clipboard."
        pasteClipboardButton.accessibilityLabel = "Just Paste from native iPhone Clipboard"
        pasteClipboardButton.accessibilityHint = "Pastes the current native iPhone Clipboard text into the active field."
        importAndPasteClipboardButton.accessibilityLabel = "Import and Paste from native iPhone Clipboard"
        importAndPasteClipboardButton.accessibilityHint = "Imports the current native iPhone Clipboard text into SweetKeyboard Clipboard and pastes it."
        clipboardButton.accessibilityLabel = "Clipboard"
        clipboardButton.accessibilityHint = "Shows SweetKeyboard Clipboard."
        clearTextButton.accessibilityLabel = "Clear text field"
        clearTextButton.accessibilityHint = "Deletes the text in the active field."
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
        if isClipboardActive {
            let pressableButton = clipboardButton
            pressableButton.setBorder(
                width: 1.5,
                colorProvider: { _ in KeyboardTheme.activeClipboardBorderColor }
            )
        }
        KeyboardTheme.applyChrome(
            to: importClipboardButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.nativeClipboardButtonCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: pasteClipboardButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.nativeClipboardButtonCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: importAndPasteClipboardButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.nativeClipboardButtonCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: clearTextButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.actionBarButtonCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: settingsButton,
            role: .utility,
            isActive: isSettingsActive,
            cornerRadius: KeyboardMetrics.actionBarButtonCornerRadius
        )
        if isSettingsActive {
            let pressableButton = settingsButton
            pressableButton.setBorder(
                width: 1.5,
                colorProvider: { _ in KeyboardTheme.activeClipboardBorderColor }
            )
        }
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

    @objc private func buttonTouchDown() {
        onPressDown?()
    }

    @objc private func copyTapped() {
        onAction?(.copy)
    }

    @objc private func importClipboardTapped() {
        onAction?(.importClipboard)
    }

    @objc private func pasteClipboardTapped() {
        onAction?(.pasteClipboard)
    }

    @objc private func importAndPasteClipboardTapped() {
        onAction?(.importAndPasteClipboard)
    }

    @objc private func clipboardTapped() {
        onAction?(.clipboard)
    }

    @objc private func clearTextTapped() {
        onAction?(.clearText)
    }

    @objc private func settingsTapped() {
        onAction?(.settings)
    }

    @objc private func hideKeyboardTapped() {
        onAction?(.hideKeyboard)
    }
}
