import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Mode {
        case keyboard
        case clipboard
        case settings
    }

    private let layoutEngine = KeyboardLayoutEngine()
    private let clipboardStore = ClipboardStore()
    private let actionKeyResolver = ActionKeyResolver()
    private let actionKeyDebugStore = ActionKeyDebugStore()

    private var isShiftEnabled = false
    private var mode: Mode = .keyboard {
        didSet {
            refreshModeUI()
        }
    }

    private let rootStack = UIStackView()
    private let actionBar = KeyboardActionBarView()
    private let keyboardContainer = UIView()
    private let keyboardRows = UIStackView()
    private let clipboardPanel = ClipboardPanelView()
    private let settingsPanel = UITextView()
    private let feedbackLabel = UILabel()

    private var globeButton: UIButton?
    private weak var actionKeyButton: UIButton?
    private var actionKeyWidthConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
        rebuildKeyboardRows()
        refreshModeUI()
        refreshActionKey()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        globeButton?.isHidden = !needsInputModeSwitchKey
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshActionKey()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        refreshActionKey()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        rootStack.axis = .vertical
        rootStack.spacing = 8

        keyboardRows.axis = .vertical
        keyboardRows.spacing = 8

        feedbackLabel.alpha = 0
        feedbackLabel.font = .preferredFont(forTextStyle: .caption1)
        feedbackLabel.textColor = .secondaryLabel
        feedbackLabel.textAlignment = .center

        settingsPanel.text = "Settings are available in the SweetKeyboard app.\n\nPrivacy:\n- Data stays on-device\n- No network calls\n- No analytics\n- No keystroke upload"
        settingsPanel.font = .preferredFont(forTextStyle: .body)
        settingsPanel.backgroundColor = .secondarySystemBackground
        settingsPanel.textColor = .label
        settingsPanel.isEditable = false
        settingsPanel.layer.cornerRadius = 12
        settingsPanel.layer.cornerCurve = .continuous
        settingsPanel.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)

        keyboardContainer.addSubview(keyboardRows)
        keyboardContainer.addSubview(clipboardPanel)
        keyboardContainer.addSubview(settingsPanel)

        keyboardRows.translatesAutoresizingMaskIntoConstraints = false
        clipboardPanel.translatesAutoresizingMaskIntoConstraints = false
        settingsPanel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyboardRows.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            keyboardRows.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            keyboardRows.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
            keyboardRows.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),

            clipboardPanel.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            clipboardPanel.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            clipboardPanel.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
            clipboardPanel.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),

            settingsPanel.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            settingsPanel.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            settingsPanel.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
            settingsPanel.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor)
        ])

        rootStack.addArrangedSubview(actionBar)
        rootStack.addArrangedSubview(keyboardContainer)
        rootStack.addArrangedSubview(feedbackLabel)

        view.addSubview(rootStack)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            keyboardContainer.heightAnchor.constraint(equalToConstant: 212),
            feedbackLabel.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func bindActions() {
        actionBar.onAction = { [weak self] action in
            guard let self else { return }

            switch action {
            case .copy:
                copySelectedText()
            case .paste:
                pasteFromSystemClipboard()
            case .clipboard:
                toggleMode(.clipboard)
            case .settings:
                toggleMode(.settings)
            }
        }

        clipboardPanel.onSelectText = { [weak self] text in
            self?.textDocumentProxy.insertText(text)
            self?.showFeedback("Inserted")
            self?.mode = .keyboard
        }
    }

    private func toggleMode(_ targetMode: Mode) {
        mode = (mode == targetMode) ? .keyboard : targetMode
    }

    private func refreshModeUI() {
        keyboardRows.isHidden = mode != .keyboard
        clipboardPanel.isHidden = mode != .clipboard
        settingsPanel.isHidden = mode != .settings

        actionBar.setClipboardActive(mode == .clipboard)
        actionBar.setSettingsActive(mode == .settings)

        if mode == .clipboard {
            clipboardPanel.render(items: clipboardStore.allItems())
        }
    }

    private func rebuildKeyboardRows() {
        keyboardRows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        addCharacterRow(layoutEngine.numberRow)

        let letters = layoutEngine.letterRows(isShiftEnabled: isShiftEnabled)
        addCharacterRow(letters[0])
        addCharacterRow(letters[1])

        let thirdRow = makeRow(distribution: .fillProportionally)
        thirdRow.addArrangedSubview(makeActionKey(title: "Shift", action: #selector(shiftTapped), width: 1.5))

        for letter in letters[2] {
            thirdRow.addArrangedSubview(makeCharacterKey(letter))
        }

        thirdRow.addArrangedSubview(makeActionKey(title: "⌫", action: #selector(backspaceTapped), width: 1.5))
        keyboardRows.addArrangedSubview(thirdRow)

        let bottomRow = makeRow(distribution: .fillProportionally)
        let globe = makeActionKey(title: "🌐", action: #selector(globeTapped), width: 1.2)
        globeButton = globe

        bottomRow.addArrangedSubview(makeActionKey(title: "123", action: #selector(noopTapped), width: 1.2))
        bottomRow.addArrangedSubview(globe)
        bottomRow.addArrangedSubview(makeActionKey(title: "space", action: #selector(spaceTapped), width: 4.5))
        let actionKey = makePrimaryActionKey(action: #selector(actionKeyTapped), width: 2.0)
        actionKeyButton = actionKey
        bottomRow.addArrangedSubview(actionKey)
        keyboardRows.addArrangedSubview(bottomRow)

        refreshActionKey()
    }

    private func addCharacterRow(_ keys: [String]) {
        let row = makeRow(distribution: .fillEqually)
        keys.forEach { row.addArrangedSubview(makeCharacterKey($0)) }
        keyboardRows.addArrangedSubview(row)
    }

    private func makeRow(distribution: UIStackView.Distribution) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = distribution
        row.alignment = .fill
        row.spacing = 6
        return row
    }

    private func makeCharacterKey(_ title: String) -> UIButton {
        let key = makeBaseKey(title: title)
        key.addTarget(self, action: #selector(characterKeyTapped(_:)), for: .touchUpInside)
        return key
    }

    private func makeActionKey(title: String, action: Selector, width: CGFloat) -> UIButton {
        let key = makeBaseKey(title: title)
        key.addTarget(self, action: action, for: .touchUpInside)
        key.widthAnchor.constraint(greaterThanOrEqualToConstant: 28 * width).isActive = true
        return key
    }

    private func makePrimaryActionKey(action: Selector, width: CGFloat) -> UIButton {
        let key = makeBaseKey(title: nil)
        key.addTarget(self, action: action, for: .touchUpInside)

        let widthConstraint = key.widthAnchor.constraint(greaterThanOrEqualToConstant: 28 * width)
        widthConstraint.isActive = true
        actionKeyWidthConstraint = widthConstraint

        key.layer.borderWidth = 0.6
        key.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        key.titleLabel?.adjustsFontSizeToFitWidth = true
        key.titleLabel?.minimumScaleFactor = 0.72
        key.accessibilityTraits.insert(.keyboardKey)

        return key
    }

    private func makeBaseKey(title: String?) -> UIButton {
        let button = UIButton(type: .system)
        if let title {
            button.setTitle(title, for: .normal)
        }

        button.titleLabel?.font = .preferredFont(forTextStyle: .title3)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.75
        button.backgroundColor = .secondarySystemFill
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return button
    }

    private func refreshActionKey() {
        let context = ActionKeyInputContext(proxy: textDocumentProxy)
        let model = actionKeyResolver.resolve(for: context)
        applyActionKeyModel(model, context: context)
        logActionKeyState(model: model, context: context)
    }

    private func applyActionKeyModel(_ model: ActionKeyModel, context: ActionKeyInputContext) {
        guard let actionKeyButton else {
            return
        }

        let preferredSymbol = model.symbolName.flatMap(primaryActionSymbol(named:))
        let useIcon = model.displayMode == .icon && preferredSymbol != nil
        let isEnabled = actionKeyResolver.isEnabled(for: model, context: context)

        actionKeyButton.setTitle(nil, for: .normal)
        actionKeyButton.setImage(nil, for: .normal)

        if useIcon, let preferredSymbol {
            actionKeyButton.setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold),
                forImageIn: .normal
            )
            actionKeyButton.setImage(preferredSymbol, for: .normal)
        } else {
            actionKeyButton.setTitle(model.fallbackTitle, for: .normal)
        }

        actionKeyButton.isEnabled = isEnabled
        actionKeyButton.backgroundColor = primaryActionBackgroundColor
        actionKeyButton.setTitleColor(.label, for: .normal)
        actionKeyButton.tintColor = .label
        actionKeyButton.layer.borderColor = primaryActionBorderColor.cgColor
        actionKeyButton.accessibilityLabel = model.accessibilityLabel
        actionKeyButton.accessibilityHint = model.accessibilityHint
        actionKeyButton.accessibilityIdentifier = "action-key-\(model.actionType.rawValue)"
        actionKeyWidthConstraint?.constant = 28 * model.minimumWidthMultiplier
    }

    private func logActionKeyState(model: ActionKeyModel, context: ActionKeyInputContext) {
        let snapshot = ActionKeyDebugSnapshot(
            id: UUID(),
            createdAt: Date(),
            actionType: model.actionType.rawValue,
            displayMode: model.displayMode.rawValue,
            visibleLabel: model.fallbackTitle,
            accessibilityLabel: model.accessibilityLabel,
            debugDescription: model.debugDescription,
            returnKeyType: context.returnKeyType?.debugName,
            keyboardType: context.keyboardType?.debugName,
            textContentType: context.textContentType,
            enablesReturnKeyAutomatically: context.enablesReturnKeyAutomatically,
            hasText: context.hasText,
            hasDocumentText: context.hasDocumentText,
            hasSelection: context.hasSelection,
            documentContextContainsLineBreaks: context.documentContextContainsLineBreaks
        )

        actionKeyDebugStore.record(snapshot)
    }

    private func primaryActionSymbol(named name: String) -> UIImage? {
        if let image = UIImage(systemName: name) {
            return image
        }

        if name == "return.left" {
            return UIImage(systemName: "arrow.turn.down.left")
        }

        return nil
    }

    private var primaryActionBackgroundColor: UIColor {
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.secondarySystemBackground
            }

            return UIColor.systemBackground
        }
    }

    private var primaryActionBorderColor: UIColor {
        UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.separator.withAlphaComponent(0.35)
            }

            return UIColor.separator.withAlphaComponent(0.18)
        }
    }

    private func copySelectedText() {
        guard let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty else {
            showFeedback("No selection")
            return
        }

        UIPasteboard.general.string = selectedText
        clipboardStore.add(text: selectedText, source: .keyboardCopy)
        showFeedback("Copied")
    }

    private func pasteFromSystemClipboard() {
        guard let pasteText = UIPasteboard.general.string, !pasteText.isEmpty else {
            showFeedback("Nothing to paste")
            return
        }

        textDocumentProxy.insertText(pasteText)
        showFeedback("Pasted")
    }

    private func showFeedback(_ message: String) {
        feedbackLabel.text = message
        UIView.animate(withDuration: 0.15, animations: {
            self.feedbackLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0.8, options: [.curveEaseOut]) {
                self.feedbackLabel.alpha = 0
            }
        }
    }

    @objc private func characterKeyTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else {
            return
        }

        textDocumentProxy.insertText(title)
        if isShiftEnabled {
            isShiftEnabled = false
            rebuildKeyboardRows()
        }
    }

    @objc private func shiftTapped() {
        isShiftEnabled.toggle()
        rebuildKeyboardRows()
    }

    @objc private func backspaceTapped() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func actionKeyTapped() {
        textDocumentProxy.insertText("\n")
    }

    @objc private func globeTapped() {
        advanceToNextInputMode()
    }

    @objc private func noopTapped() {
        // Placeholder for future alternate layouts.
    }
}
