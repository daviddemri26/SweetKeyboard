import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Mode {
        case keyboard
        case clipboard
        case settings
    }

    private enum KeyboardLayoutMode {
        case letters
        case symbols
    }

    private enum ShiftState {
        case off
        case enabled
        case locked
    }

    private let layoutEngine = KeyboardLayoutEngine()
    private let clipboardStore = ClipboardStore()
    private let actionKeyResolver = ActionKeyResolver()
    private let actionKeyDebugStore = ActionKeyDebugStore()

    private let shiftDoubleTapInterval: TimeInterval = 0.35
    private let cursorMovementRepeatDelay: TimeInterval = 1
    private let cursorMovementRepeatInterval: TimeInterval = 0.1
    private var shiftState: ShiftState = .off
    private var lastShiftTapAt: Date?
    private var keyboardLayoutMode: KeyboardLayoutMode = .letters
    private var activeCursorMovementOffset: Int?
    private weak var activeCursorMovementButton: UIButton?
    private var cursorMovementDelayTimer: Timer?
    private var cursorMovementRepeatTimer: Timer?
    private var didRepeatCursorMovement = false
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

    private weak var actionKeyButton: UIButton?
    private var actionKeyWidthConstraint: NSLayoutConstraint?
    private var inputViewHeightConstraint: NSLayoutConstraint?
    private var keyboardContainerHeightConstraint: NSLayoutConstraint?
    private var keyboardRowsBottomConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerTraitObservers()
        updateKeyboardSizingIfNeeded()
        bindActions()
        rebuildKeyboardRows()
        refreshModeUI()
        refreshActionKey()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        actionBar.setGlobeHidden(!needsInputModeSwitchKey)
        updateKeyboardSizingIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateKeyboardSizingIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopCursorMovementRepeat()
    }

    private func registerTraitObservers() {
        registerForTraitChanges([
            UITraitUserInterfaceStyle.self,
            UITraitAccessibilityContrast.self,
            UITraitPreferredContentSizeCategory.self
        ]) { (self: Self, _) in
            self.applyTheme()
            self.refreshActionKey()
        }
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
        view.backgroundColor = KeyboardTheme.keyboardBackground

        rootStack.axis = .vertical
        rootStack.alignment = .fill
        rootStack.distribution = .fill
        rootStack.spacing = KeyboardMetrics.utilityRowSpacing

        keyboardRows.axis = .vertical
        keyboardRows.alignment = .fill
        keyboardRows.distribution = .fill
        keyboardRows.spacing = KeyboardMetrics.keyboardRowSpacing

        actionBar.setContentHuggingPriority(.required, for: .vertical)
        actionBar.setContentCompressionResistancePriority(.required, for: .vertical)
        keyboardContainer.setContentHuggingPriority(.required, for: .vertical)
        keyboardContainer.setContentCompressionResistancePriority(.required, for: .vertical)

        feedbackLabel.alpha = 0
        feedbackLabel.font = .preferredFont(forTextStyle: .caption1)
        feedbackLabel.textAlignment = .center
        feedbackLabel.backgroundColor = KeyboardTheme.feedbackBackground
        feedbackLabel.textColor = KeyboardTheme.keyLabelColor
        feedbackLabel.layer.cornerRadius = KeyboardMetrics.feedbackCornerRadius
        feedbackLabel.layer.cornerCurve = .continuous
        feedbackLabel.clipsToBounds = true

        settingsPanel.text = "Settings are available in the SweetKeyboard app.\n\nPrivacy:\n- Data stays on-device\n- No network calls\n- No analytics\n- No keystroke upload"
        settingsPanel.font = .preferredFont(forTextStyle: .body)
        settingsPanel.backgroundColor = KeyboardTheme.panelBackground
        settingsPanel.textColor = KeyboardTheme.keyLabelColor
        settingsPanel.isEditable = false
        settingsPanel.layer.cornerRadius = KeyboardMetrics.settingsPanelCornerRadius
        settingsPanel.layer.cornerCurve = .continuous
        settingsPanel.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)

        keyboardContainer.addSubview(keyboardRows)
        keyboardContainer.addSubview(clipboardPanel)
        keyboardContainer.addSubview(settingsPanel)
        view.addSubview(feedbackLabel)
        keyboardRows.translatesAutoresizingMaskIntoConstraints = false
        clipboardPanel.translatesAutoresizingMaskIntoConstraints = false
        settingsPanel.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false

        keyboardRowsBottomConstraint = keyboardRows.bottomAnchor.constraint(
            equalTo: keyboardContainer.bottomAnchor,
            constant: -KeyboardMetrics.minimumKeyboardBottomInset
        )
        keyboardContainerHeightConstraint = keyboardContainer.heightAnchor.constraint(
            equalToConstant: KeyboardMetrics.keyboardContainerHeight(
                bottomInset: KeyboardMetrics.minimumKeyboardBottomInset
            )
        )

        NSLayoutConstraint.activate([
            keyboardRows.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            keyboardRows.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            keyboardRows.topAnchor.constraint(equalTo: keyboardContainer.topAnchor, constant: KeyboardMetrics.keyboardTopPadding),

            clipboardPanel.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            clipboardPanel.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            clipboardPanel.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
            clipboardPanel.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),

            settingsPanel.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            settingsPanel.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            settingsPanel.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
            settingsPanel.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),

            feedbackLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -KeyboardMetrics.feedbackBottomInset),
            feedbackLabel.heightAnchor.constraint(equalToConstant: KeyboardMetrics.feedbackHeight),
            feedbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 48),
            feedbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -48),
            keyboardRowsBottomConstraint!
        ])

        rootStack.addArrangedSubview(actionBar)
        rootStack.addArrangedSubview(keyboardContainer)

        view.addSubview(rootStack)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: KeyboardMetrics.outerHorizontalPadding),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -KeyboardMetrics.outerHorizontalPadding),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -KeyboardMetrics.outerBottomPadding),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: KeyboardMetrics.outerTopPadding),
            keyboardContainerHeightConstraint!
        ])

        applyTheme()
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
            case .globe:
                globeTapped()
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

    private func applyTheme() {
        view.backgroundColor = KeyboardTheme.keyboardBackground
        keyboardContainer.backgroundColor = .clear
        settingsPanel.backgroundColor = KeyboardTheme.panelBackground
        settingsPanel.textColor = KeyboardTheme.keyLabelColor
        feedbackLabel.backgroundColor = KeyboardTheme.feedbackBackground
        feedbackLabel.textColor = KeyboardTheme.keyLabelColor
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
        stopCursorMovementRepeat()
        keyboardRows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch keyboardLayoutMode {
        case .letters:
            rebuildLetterKeyboardRows()
        case .symbols:
            rebuildSymbolKeyboardRows()
        }

        refreshActionKey()
    }

    private func rebuildLetterKeyboardRows() {
        addCharacterRow(layoutEngine.numberRow)

        let letters = layoutEngine.letterRows(isShiftEnabled: isShiftActive)
        addCharacterRow(letters[0])
        addCharacterRow(letters[1])

        let thirdRow = makeRow(distribution: .fillProportionally)
        thirdRow.addArrangedSubview(makeShiftKey(width: 1.5))

        for letter in letters[2] {
            thirdRow.addArrangedSubview(makeCharacterKey(letter))
        }

        thirdRow.addArrangedSubview(makeActionKey(title: "⌫", action: #selector(backspaceTapped), width: 1.5))
        keyboardRows.addArrangedSubview(thirdRow)

        let bottomRow = makeRow(distribution: .fillProportionally)
        bottomRow.addArrangedSubview(makeActionSymbolKey(symbolName: "command", action: #selector(symbolKeyboardTapped), width: 1.35))
        bottomRow.addArrangedSubview(makeCharacterActionKey(title: ",", action: #selector(characterKeyTapped(_:)), width: 0.8))
        bottomRow.addArrangedSubview(makeCharacterActionKey(title: ".", action: #selector(characterKeyTapped(_:)), width: 0.8))
        bottomRow.addArrangedSubview(makeCharacterActionKey(title: "?", action: #selector(characterKeyTapped(_:)), width: 0.8))
        bottomRow.addArrangedSubview(makeCharacterActionKey(title: "", action: #selector(spaceTapped), width: 3.2))
        let actionKey = makePrimaryActionKey(action: #selector(actionKeyTapped), width: 1.6)
        actionKeyButton = actionKey
        bottomRow.addArrangedSubview(actionKey)
        keyboardRows.addArrangedSubview(bottomRow)
    }

    private func rebuildSymbolKeyboardRows() {
        for rowKeys in layoutEngine.symbolRows {
            addCharacterRow(rowKeys)
        }

        let punctuationRow = makeRow(distribution: .fillProportionally)
        for symbol in layoutEngine.symbolPunctuationRow {
            punctuationRow.addArrangedSubview(
                makeCharacterActionKey(
                    title: symbol,
                    action: #selector(characterKeyTapped(_:)),
                    width: 1
                )
            )
        }
        punctuationRow.addArrangedSubview(makeCursorMovementKey(symbolName: "arrow.left", offset: -1, width: 1.15))
        punctuationRow.addArrangedSubview(makeCursorMovementKey(symbolName: "arrow.right", offset: 1, width: 1.15))
        punctuationRow.addArrangedSubview(makeActionKey(title: "⌫", action: #selector(backspaceTapped), width: 1.5))
        keyboardRows.addArrangedSubview(punctuationRow)

        let bottomRow = makeRow(distribution: .fillProportionally)
        bottomRow.addArrangedSubview(makeActionKey(title: "ABC", action: #selector(letterKeyboardTapped), width: 1.35))
        bottomRow.addArrangedSubview(makeCharacterActionKey(title: "", action: #selector(spaceTapped), width: 4.8))
        let actionKey = makePrimaryActionKey(action: #selector(actionKeyTapped), width: 1.6)
        actionKeyButton = actionKey
        bottomRow.addArrangedSubview(actionKey)
        keyboardRows.addArrangedSubview(bottomRow)
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
        row.spacing = KeyboardMetrics.keyboardKeySpacing
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        return row
    }

    private func updateKeyboardSizingIfNeeded() {
        let bottomInset = KeyboardMetrics.keyboardBottomInset(for: view.safeAreaInsets)
        let containerHeight = KeyboardMetrics.keyboardContainerHeight(bottomInset: bottomInset)
        let totalHeight = KeyboardMetrics.totalKeyboardHeight(bottomInset: bottomInset)

        if keyboardRowsBottomConstraint?.constant != -bottomInset {
            keyboardRowsBottomConstraint?.constant = -bottomInset
        }

        if keyboardContainerHeightConstraint?.constant != containerHeight {
            keyboardContainerHeightConstraint?.constant = containerHeight
        }

        let heightAnchorItem: UIView = inputView ?? view
        if inputViewHeightConstraint?.firstItem !== heightAnchorItem {
            inputViewHeightConstraint?.isActive = false
            inputViewHeightConstraint = heightAnchorItem.heightAnchor.constraint(equalToConstant: totalHeight)
            inputViewHeightConstraint?.priority = .required
            inputViewHeightConstraint?.isActive = true
        } else if inputViewHeightConstraint?.constant != totalHeight {
            inputViewHeightConstraint?.constant = totalHeight
        }
    }

    private func makeCharacterKey(_ title: String) -> UIButton {
        let key = makeBaseKey(title: title, role: .character)
        key.addTarget(self, action: #selector(characterKeyTapped(_:)), for: .touchUpInside)
        return key
    }

    private func makeActionKey(title: String, action: Selector, width: CGFloat) -> UIButton {
        let key = makeBaseKey(title: title, role: .system)
        if title == "⌫" {
            if let pressableKey = key as? KeyboardPressableButton {
                pressableKey.setTitleFonts(
                    normal: UIFont.systemFont(ofSize: KeyboardMetrics.backspaceKeyFontSize, weight: .regular),
                    highlighted: UIFont.systemFont(ofSize: KeyboardMetrics.backspaceKeyFontSize, weight: .semibold)
                )
            } else {
                key.titleLabel?.font = UIFont.systemFont(ofSize: KeyboardMetrics.backspaceKeyFontSize, weight: .regular)
            }
        }
        key.addTarget(self, action: action, for: .touchUpInside)
        key.widthAnchor.constraint(greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * width).isActive = true
        return key
    }

    private func makeActionSymbolKey(symbolName: String, action: Selector, width: CGFloat) -> UIButton {
        let key = makeBaseKey(title: nil, role: .system)
        let normalConfiguration = UIImage.SymbolConfiguration(
            pointSize: KeyboardMetrics.systemKeyFontSize,
            weight: .medium
        )
        let highlightedConfiguration = UIImage.SymbolConfiguration(
            pointSize: KeyboardMetrics.systemKeyFontSize,
            weight: .semibold
        )

        if let pressableKey = key as? KeyboardPressableButton {
            pressableKey.setSymbolConfigurations(
                normal: normalConfiguration,
                highlighted: highlightedConfiguration
            )
            pressableKey.setForegroundColors(
                normal: KeyboardTheme.keyLabelColor,
                highlighted: KeyboardTheme.keyLabelColor
            )
        } else {
            key.setPreferredSymbolConfiguration(normalConfiguration, forImageIn: .normal)
            key.tintColor = KeyboardTheme.keyLabelColor
        }

        let symbolImage = UIImage(systemName: symbolName)
        if let pressableKey = key as? KeyboardPressableButton {
            pressableKey.setSymbolImage(symbolImage)
        } else {
            key.setImage(symbolImage?.withRenderingMode(.alwaysTemplate), for: .normal)
            key.setImage(symbolImage?.withRenderingMode(.alwaysTemplate), for: .highlighted)
        }
        key.addTarget(self, action: action, for: .touchUpInside)
        key.widthAnchor.constraint(greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * width).isActive = true
        return key
    }

    private func makeShiftKey(width: CGFloat) -> UIButton {
        let key = makeBaseKey(title: nil, role: .system)
        let symbolName: String
        let accessibilityLabel: String

        switch shiftState {
        case .off:
            symbolName = "shift"
            accessibilityLabel = "Enable Shift"
        case .enabled:
            symbolName = "shift.fill"
            accessibilityLabel = "Disable Shift"
        case .locked:
            symbolName = "capslock.fill"
            accessibilityLabel = "Disable Caps Lock"
        }

        let normalConfiguration = UIImage.SymbolConfiguration(
            pointSize: KeyboardMetrics.actionSymbolPointSize,
            weight: .medium
        )
        let highlightedConfiguration = UIImage.SymbolConfiguration(
            pointSize: KeyboardMetrics.actionSymbolPointSize,
            weight: .semibold
        )
        if let pressableKey = key as? KeyboardPressableButton {
            pressableKey.setSymbolConfigurations(
                normal: normalConfiguration,
                highlighted: highlightedConfiguration
            )
        } else {
            key.setPreferredSymbolConfiguration(normalConfiguration, forImageIn: .normal)
        }
        key.setImage(UIImage(systemName: symbolName), for: .normal)
        key.accessibilityLabel = accessibilityLabel
        key.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
        key.widthAnchor.constraint(greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * width).isActive = true
        return key
    }

    private func makeCharacterActionKey(title: String, action: Selector, width: CGFloat) -> UIButton {
        let key = makeBaseKey(title: title, role: .character)
        key.addTarget(self, action: action, for: .touchUpInside)
        key.widthAnchor.constraint(greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * width).isActive = true
        return key
    }

    private func makePrimaryActionKey(action: Selector, width: CGFloat) -> UIButton {
        let key = makeBaseKey(title: nil, role: .primaryAction)
        key.addTarget(self, action: action, for: .touchUpInside)

        let widthConstraint = key.widthAnchor.constraint(greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * width)
        widthConstraint.isActive = true
        actionKeyWidthConstraint = widthConstraint

        if let pressableKey = key as? KeyboardPressableButton {
            pressableKey.setTitleFonts(
                normal: UIFont.systemFont(ofSize: KeyboardMetrics.primaryActionFontSize, weight: .regular),
                highlighted: UIFont.systemFont(ofSize: KeyboardMetrics.primaryActionFontSize, weight: .semibold)
            )
        } else {
            key.titleLabel?.font = UIFont.systemFont(ofSize: KeyboardMetrics.primaryActionFontSize, weight: .regular)
        }
        key.titleLabel?.adjustsFontSizeToFitWidth = true
        key.titleLabel?.minimumScaleFactor = 0.72
        key.accessibilityTraits.insert(.keyboardKey)

        return key
    }

    private func makeCursorMovementKey(symbolName: String, offset: Int, width: CGFloat) -> UIButton {
        let key = makeActionSymbolKey(symbolName: symbolName, action: #selector(cursorMovementKeyTapped(_:)), width: width)
        key.tag = offset
        key.accessibilityLabel = (offset < 0) ? "Move cursor left" : "Move cursor right"
        key.accessibilityHint = "Moves the insertion point by one character."
        key.addTarget(self, action: #selector(cursorMovementTouchDown(_:)), for: .touchDown)
        key.addTarget(self, action: #selector(cursorMovementTouchEnded(_:)), for: .touchUpInside)
        key.addTarget(self, action: #selector(cursorMovementTouchEnded(_:)), for: .touchUpOutside)
        key.addTarget(self, action: #selector(cursorMovementTouchEnded(_:)), for: .touchCancel)
        key.addTarget(self, action: #selector(cursorMovementTouchEnded(_:)), for: .touchDragExit)
        return key
    }

    private func makeBaseKey(title: String?, role: KeyboardButtonRole) -> UIButton {
        let button = KeyboardPressableButton(type: .custom)
        if let title {
            button.setTitle(title, for: .normal)
        }

        let normalFont: UIFont
        let highlightedFont: UIFont

        switch role {
        case .character:
            normalFont = UIFont.systemFont(ofSize: KeyboardMetrics.characterKeyFontSize, weight: .regular)
            highlightedFont = UIFont.systemFont(ofSize: KeyboardMetrics.characterKeyFontSize, weight: .semibold)
        case .system:
            normalFont = UIFont.systemFont(ofSize: KeyboardMetrics.systemKeyFontSize, weight: .regular)
            highlightedFont = UIFont.systemFont(ofSize: KeyboardMetrics.systemKeyFontSize, weight: .semibold)
        case .primaryAction:
            normalFont = UIFont.systemFont(ofSize: KeyboardMetrics.primaryActionFontSize, weight: .regular)
            highlightedFont = UIFont.systemFont(ofSize: KeyboardMetrics.primaryActionFontSize, weight: .semibold)
        case .utility:
            normalFont = UIFont.systemFont(ofSize: KeyboardMetrics.utilityButtonFontSize, weight: .regular)
            highlightedFont = UIFont.systemFont(ofSize: KeyboardMetrics.utilityButtonFontSize, weight: .semibold)
        }

        button.setTitleFonts(normal: normalFont, highlighted: highlightedFont)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.75
        KeyboardTheme.applyChrome(
            to: button,
            role: role,
            cornerRadius: KeyboardMetrics.keyCornerRadius
        )
        button.heightAnchor.constraint(equalToConstant: KeyboardMetrics.keyboardRowHeight).isActive = true
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
        let isGoAction = model.actionType == .go

        actionKeyButton.setTitle(nil, for: .normal)
        actionKeyButton.setImage(nil, for: .normal)

        if useIcon, let preferredSymbol {
            let normalConfiguration = UIImage.SymbolConfiguration(
                pointSize: KeyboardMetrics.actionSymbolPointSize,
                weight: .medium
            )
            let highlightedConfiguration = UIImage.SymbolConfiguration(
                pointSize: KeyboardMetrics.actionSymbolPointSize,
                weight: .semibold
            )
            if let pressableButton = actionKeyButton as? KeyboardPressableButton {
                pressableButton.setSymbolConfigurations(
                    normal: normalConfiguration,
                    highlighted: highlightedConfiguration
                )
            } else {
                actionKeyButton.setPreferredSymbolConfiguration(normalConfiguration, forImageIn: .normal)
            }
            if let pressableButton = actionKeyButton as? KeyboardPressableButton {
                pressableButton.setSymbolImage(preferredSymbol)
            } else {
                let templatedImage = preferredSymbol.withRenderingMode(.alwaysTemplate)
                actionKeyButton.setImage(templatedImage, for: .normal)
                actionKeyButton.setImage(templatedImage, for: .highlighted)
            }
        } else {
            actionKeyButton.setTitle(model.fallbackTitle, for: .normal)
        }

        actionKeyButton.isEnabled = isEnabled
        KeyboardTheme.applyChrome(
            to: actionKeyButton,
            role: .primaryAction,
            cornerRadius: KeyboardMetrics.keyCornerRadius
        )
        if let pressableButton = actionKeyButton as? KeyboardPressableButton {
            let normalBackground = isGoAction ? goActionBackgroundColor : KeyboardTheme.background(for: .primaryAction)
            let highlightedBackground = KeyboardTheme.pressedBackground(for: .primaryAction)
            pressableButton.setBackgroundColors(normal: normalBackground, highlighted: highlightedBackground)
            pressableButton.setForegroundColors(
                normal: isGoAction ? .white : KeyboardTheme.keyLabelColor,
                highlighted: isGoAction ? KeyboardTheme.goActionPressedForegroundColor : KeyboardTheme.keyLabelColor
            )
        } else {
            actionKeyButton.setTitleColor(isGoAction ? .white : KeyboardTheme.keyLabelColor, for: .normal)
            actionKeyButton.setTitleColor(
                isGoAction ? KeyboardTheme.goActionPressedForegroundColor : KeyboardTheme.keyLabelColor,
                for: .highlighted
            )
            actionKeyButton.tintColor = isGoAction ? .white : KeyboardTheme.keyLabelColor
            actionKeyButton.backgroundColor = isGoAction ? goActionBackgroundColor : actionKeyButton.backgroundColor
        }
        actionKeyButton.layer.borderColor = UIColor.clear.cgColor
        actionKeyButton.layer.borderWidth = 0
        actionKeyButton.accessibilityLabel = model.accessibilityLabel
        actionKeyButton.accessibilityHint = model.accessibilityHint
        actionKeyButton.accessibilityIdentifier = "action-key-\(model.actionType.rawValue)"
        actionKeyWidthConstraint?.constant = KeyboardMetrics.keyUnitWidth * model.minimumWidthMultiplier
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

    private var goActionBackgroundColor: UIColor {
        UIColor(red: 52 / 255, green: 120 / 255, blue: 245 / 255, alpha: 1)
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
        if shiftState == .enabled {
            shiftState = .off
            lastShiftTapAt = nil
            rebuildKeyboardRows()
        }
    }

    @objc private func shiftTapped() {
        let now = Date()

        if let lastShiftTapAt, now.timeIntervalSince(lastShiftTapAt) <= shiftDoubleTapInterval {
            shiftState = (shiftState == .locked) ? .off : .locked
            self.lastShiftTapAt = nil
            rebuildKeyboardRows()
            return
        }

        switch shiftState {
        case .off:
            shiftState = .enabled
        case .enabled, .locked:
            shiftState = .off
        }

        lastShiftTapAt = now
        rebuildKeyboardRows()
    }

    @objc private func backspaceTapped() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func cursorMovementTouchDown(_ sender: UIButton) {
        stopCursorMovementRepeat()

        activeCursorMovementOffset = sender.tag
        activeCursorMovementButton = sender
        didRepeatCursorMovement = false

        cursorMovementDelayTimer = scheduleCursorMovementTimer(
            interval: cursorMovementRepeatDelay,
            repeats: false
        ) { [weak self, weak sender] _ in
            guard
                let self,
                let sender,
                self.activeCursorMovementButton === sender,
                self.activeCursorMovementOffset == sender.tag
            else {
                return
            }

            self.didRepeatCursorMovement = true
            self.moveCursor(by: sender.tag)
            self.cursorMovementRepeatTimer = self.scheduleCursorMovementTimer(
                interval: self.cursorMovementRepeatInterval,
                repeats: true
            ) { [weak self, weak sender] _ in
                guard
                    let self,
                    let sender,
                    self.activeCursorMovementButton === sender,
                    self.activeCursorMovementOffset == sender.tag
                else {
                    return
                }

                self.moveCursor(by: sender.tag)
            }
        }
    }

    @objc private func cursorMovementKeyTapped(_ sender: UIButton) {
        defer {
            stopCursorMovementRepeat()
        }

        guard !didRepeatCursorMovement else {
            return
        }

        moveCursor(by: sender.tag)
    }

    @objc private func cursorMovementTouchEnded(_ sender: UIButton) {
        stopCursorMovementRepeat()
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

    @objc private func symbolKeyboardTapped() {
        keyboardLayoutMode = .symbols
        rebuildKeyboardRows()
    }

    @objc private func letterKeyboardTapped() {
        keyboardLayoutMode = .letters
        rebuildKeyboardRows()
    }

    private func moveCursor(by offset: Int) {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
    }

    private func stopCursorMovementRepeat() {
        cursorMovementDelayTimer?.invalidate()
        cursorMovementRepeatTimer?.invalidate()
        cursorMovementDelayTimer = nil
        cursorMovementRepeatTimer = nil
        activeCursorMovementOffset = nil
        activeCursorMovementButton = nil
        didRepeatCursorMovement = false
    }

    private func scheduleCursorMovementTimer(
        interval: TimeInterval,
        repeats: Bool,
        handler: @escaping (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: handler)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private var isShiftActive: Bool {
        shiftState != .off
    }
}
