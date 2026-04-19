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

    private enum DisplayMode {
        case basic
        case clipboard
    }

    private let layoutEngine = KeyboardLayoutEngine()
    private let clipboardStore = ClipboardStore()
    private let actionKeyResolver = ActionKeyResolver()
    private let actionKeyDebugStore = ActionKeyDebugStore()
    private let sharedSettingsStore = SharedKeyboardSettingsStore()
    private let capabilityStatusStore = KeyboardCapabilityStatusStore()

    private let shiftDoubleTapInterval: TimeInterval = 0.35
    private let accentHoldDelay: TimeInterval = 0.5
    private let keyRepeatDelay: TimeInterval = 0.8
    private let keyRepeatInterval: TimeInterval = 0.1
    private var shiftState: ShiftState = .off
    private var lastShiftTapAt: Date?
    private var keyboardLayoutMode: KeyboardLayoutMode = .letters
    private var isEmailFieldActive = false
    private var accentState: AccentReplacementState?
    private var displayMode: DisplayMode = .basic
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
    private let settingsPanel = KeyboardSettingsPanelView()
    private let feedbackLabel = UILabel()
    private lazy var feedbackPresenter = KeyboardFeedbackPresenter(label: feedbackLabel)
    private lazy var backspaceRepeatController = KeyboardKeyRepeatController(
        delay: keyRepeatDelay,
        repeatInterval: keyRepeatInterval
    )
    private lazy var characterHoldController = KeyboardLongPressController(delay: accentHoldDelay)
    private lazy var cursorRepeatController = KeyboardKeyRepeatController(
        delay: keyRepeatDelay,
        repeatInterval: keyRepeatInterval
    )

    private weak var actionKeyButton: UIButton?
    private var actionKeyWidthConstraint: NSLayoutConstraint?
    private var inputViewHeightConstraint: NSLayoutConstraint?
    private var keyboardContainerHeightConstraint: NSLayoutConstraint?
    private var keyboardRowsBottomConstraint: NSLayoutConstraint?

    private var desiredClipboardModeEnabled: Bool {
        sharedSettingsStore.load().clipboardModeEnabled
    }

    private var effectiveDisplayMode: DisplayMode {
        (hasFullAccess && desiredClipboardModeEnabled) ? .clipboard : .basic
    }

    private var shouldShowInlineSettingsKey: Bool {
        displayMode == .basic && keyboardLayoutMode == .symbols
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerTraitObservers()
        bindActions()
        reloadFeatureState(rebuildKeyboard: true)
        refreshActionKey()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mode = .keyboard
        keyboardLayoutMode = .letters
        clearAccentState(rebuild: false)
        reloadFeatureState(rebuildKeyboard: true)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateKeyboardSizingIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateKeyboardSizingIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopKeyRepeats()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshActionKey()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        refreshActionKey()
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
            case .settings:
                toggleMode(.settings)
            }
        }

        clipboardPanel.onSelectText = { [weak self] text in
            self?.textDocumentProxy.insertText(text)
            self?.feedbackPresenter.show("Inserted")
            self?.mode = .keyboard
        }

        settingsPanel.onClipboardModeChanged = { [weak self] isEnabled in
            self?.handleClipboardModeChanged(isEnabled)
        }

        settingsPanel.onDone = { [weak self] in
            self?.returnToLetterKeyboard()
        }
    }

    private func reloadFeatureState(rebuildKeyboard: Bool) {
        if hasFullAccess {
            capabilityStatusStore.confirmFullAccessNow()
        }

        let previousDisplayMode = displayMode
        displayMode = effectiveDisplayMode
        actionBar.isHidden = displayMode == .basic

        if displayMode == .basic && mode == .clipboard {
            mode = .keyboard
        }

        updateSettingsPanel()
        updateKeyboardSizingIfNeeded()

        if rebuildKeyboard || previousDisplayMode != displayMode {
            rebuildKeyboardRows()
        } else {
            refreshModeUI()
        }
    }

    private func updateSettingsPanel() {
        let helperText: String?
        let showsClipboardToggle = true
        let isClipboardToggleEnabled = hasFullAccess

        if hasFullAccess && desiredClipboardModeEnabled {
            helperText = "Turn this off to use SweetKeyboard in typing-only mode. Clipboard data stays local on this device."
        } else if hasFullAccess {
            helperText = "Turn this on to show Copy, Paste, Clipboard, and Settings above the keyboard."
        } else {
            helperText = "Clipboard tools require Full Access. Enable Full Access in iPhone Settings, then reopen SweetKeyboard to turn this on."
        }

        settingsPanel.render(
            isClipboardModeEnabled: desiredClipboardModeEnabled,
            showsClipboardToggle: showsClipboardToggle,
            isClipboardToggleEnabled: isClipboardToggleEnabled,
            helperText: helperText
        )
    }

    private func applyTheme() {
        view.backgroundColor = KeyboardTheme.keyboardBackground
        keyboardContainer.backgroundColor = .clear
        feedbackLabel.backgroundColor = KeyboardTheme.feedbackBackground
        feedbackLabel.textColor = KeyboardTheme.keyLabelColor
    }

    private func toggleMode(_ targetMode: Mode) {
        if targetMode == .clipboard && displayMode != .clipboard {
            return
        }

        clearAccentState(rebuild: mode == .keyboard)
        mode = (mode == targetMode) ? .keyboard : targetMode
    }

    private func refreshModeUI() {
        let isClipboardVisible = displayMode == .clipboard && mode == .clipboard

        keyboardRows.isHidden = mode != .keyboard
        clipboardPanel.isHidden = !isClipboardVisible
        settingsPanel.isHidden = mode != .settings

        actionBar.setClipboardActive(isClipboardVisible)
        actionBar.setSettingsActive(displayMode == .clipboard && mode == .settings)

        if isClipboardVisible {
            clipboardPanel.render(items: clipboardStore.allItems())
        }
    }

    private func rebuildKeyboardRows() {
        stopKeyRepeats()
        actionKeyButton = nil
        actionKeyWidthConstraint = nil
        keyboardRows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let rowSpecs: [KeyboardRowSpec]
        switch keyboardLayoutMode {
        case .letters:
            rowSpecs = layoutEngine.letterRows(
                isShiftEnabled: isShiftActive,
                isEmailField: isEmailFieldActive,
                accentState: accentState
            )
        case .symbols:
            rowSpecs = layoutEngine.symbolRows(showInlineSettingsKey: shouldShowInlineSettingsKey)
        }

        for rowSpec in rowSpecs {
            keyboardRows.addArrangedSubview(makeRow(from: rowSpec))
        }

        refreshActionKey()
    }

    private func makeRow(from spec: KeyboardRowSpec) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fill
        row.alignment = .fill
        row.spacing = KeyboardMetrics.keyboardKeySpacing
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)

        guard let firstItem = spec.items.first else {
            return row
        }

        let referenceButton = makeKey(for: firstItem.kind)
        row.addArrangedSubview(referenceButton)
        let referenceMinimumWidthConstraint = referenceButton.widthAnchor.constraint(
            greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * firstItem.width.minimumUnits
        )
        referenceMinimumWidthConstraint.isActive = true

        if case .primaryAction = firstItem.kind {
            actionKeyButton = referenceButton
            actionKeyWidthConstraint = referenceMinimumWidthConstraint
        }

        let referenceShare = max(firstItem.width.share, 0.001)

        for item in spec.items.dropFirst() {
            let button = makeKey(for: item.kind)
            row.addArrangedSubview(button)

            let minimumWidthConstraint = button.widthAnchor.constraint(
                greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * item.width.minimumUnits
            )
            minimumWidthConstraint.isActive = true

            let widthRatioConstraint = button.widthAnchor.constraint(
                equalTo: referenceButton.widthAnchor,
                multiplier: max(item.width.share, 0.001) / referenceShare
            )
            widthRatioConstraint.priority = UILayoutPriority(999)
            widthRatioConstraint.isActive = true

            if case .primaryAction = item.kind {
                actionKeyButton = button
                actionKeyWidthConstraint = minimumWidthConstraint
            }
        }

        return row
    }

    private func updateKeyboardSizingIfNeeded() {
        let bottomInset = KeyboardMetrics.keyboardBottomInset(for: view.safeAreaInsets)
        let containerHeight = KeyboardMetrics.keyboardContainerHeight(bottomInset: bottomInset)
        let totalHeight = KeyboardMetrics.totalKeyboardHeight(
            bottomInset: bottomInset,
            showsUtilityRow: displayMode == .clipboard
        )

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
        key.addTarget(self, action: #selector(characterKeyTouchDown(_:)), for: .touchDown)
        key.addTarget(self, action: #selector(characterKeyTapped(_:)), for: .touchUpInside)
        key.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: .touchUpOutside)
        key.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: .touchCancel)
        key.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: .touchDragExit)
        return key
    }

    private func makeKey(for kind: KeyboardKeyKind) -> UIButton {
        switch kind {
        case .character(let title):
            return makeCharacterKey(title)
        case .shift:
            return makeShiftKey()
        case .backspace:
            return makeActionKey(title: "⌫")
        case .space:
            return makeCharacterActionKey(title: "", action: #selector(spaceTapped))
        case .symbolToggle:
            let key = makeActionSymbolKey(symbolName: "command", action: #selector(symbolKeyboardTapped))
            applyFunctionKeyBorder(to: key)
            return key
        case .letterToggle:
            let key = makeActionKey(title: "ABC", action: #selector(letterKeyboardTapped))
            applyFunctionKeyBorder(to: key)
            return key
        case .primaryAction:
            return makePrimaryActionKey(action: #selector(actionKeyTapped))
        case .cursor(let offset, let symbolName):
            return makeCursorMovementKey(symbolName: symbolName, offset: offset)
        case .inlineSettings:
            return makeInlineSettingsKey()
        }
    }

    private func makeActionKey(title: String, action: Selector? = nil) -> UIButton {
        let key = makeBaseKey(title: title, role: .system)
        if title == "⌫" {
            applyFunctionKeyBorder(to: key)
            if let pressableKey = key as? KeyboardPressableButton {
                pressableKey.setTitleFonts(
                    normal: UIFont.systemFont(ofSize: KeyboardMetrics.backspaceKeyFontSize, weight: .regular),
                    highlighted: UIFont.systemFont(ofSize: KeyboardMetrics.backspaceKeyFontSize, weight: .semibold)
                )
            } else {
                key.titleLabel?.font = UIFont.systemFont(ofSize: KeyboardMetrics.backspaceKeyFontSize, weight: .regular)
            }
            key.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
            key.addTarget(self, action: #selector(backspaceKeyTapped(_:)), for: .touchUpInside)
            key.addTarget(self, action: #selector(backspaceTouchEnded(_:)), for: .touchUpOutside)
            key.addTarget(self, action: #selector(backspaceTouchEnded(_:)), for: .touchCancel)
            key.addTarget(self, action: #selector(backspaceTouchEnded(_:)), for: .touchDragExit)
        } else if let action {
            key.addTarget(self, action: action, for: .touchUpInside)
        }
        return key
    }

    private func makeActionSymbolKey(symbolName: String, action: Selector? = nil) -> UIButton {
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

        if let action {
            key.addTarget(self, action: action, for: .touchUpInside)
        }

        return key
    }

    private func makeShiftKey() -> UIButton {
        let key = makeBaseKey(title: nil, role: .system)
        applyFunctionKeyBorder(to: key)
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
            pressableKey.setForegroundColors(
                normal: KeyboardTheme.keyLabelColor,
                highlighted: KeyboardTheme.keyLabelColor
            )
        } else {
            key.setPreferredSymbolConfiguration(normalConfiguration, forImageIn: .normal)
            key.tintColor = KeyboardTheme.keyLabelColor
        }
        let symbolImage = UIImage(systemName: symbolName)?.withRenderingMode(.alwaysTemplate)
        key.setImage(symbolImage, for: .normal)
        key.setImage(symbolImage, for: .highlighted)
        key.accessibilityLabel = accessibilityLabel
        key.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
        return key
    }

    private func makeCharacterActionKey(title: String, action: Selector) -> UIButton {
        let key = makeBaseKey(title: title, role: .character)
        key.addTarget(self, action: action, for: .touchUpInside)
        return key
    }

    private func makePrimaryActionKey(action: Selector) -> UIButton {
        let key = makeBaseKey(title: nil, role: .primaryAction)
        key.addTarget(self, action: action, for: .touchUpInside)

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

    private func makeCursorMovementKey(symbolName: String, offset: Int) -> UIButton {
        let key = makeActionSymbolKey(symbolName: symbolName, action: #selector(cursorMovementKeyTapped(_:)))

        let normalConfiguration = UIImage.SymbolConfiguration(
            pointSize: KeyboardMetrics.cursorSymbolPointSize,
            weight: .semibold
        )
        let highlightedConfiguration = UIImage.SymbolConfiguration(
            pointSize: KeyboardMetrics.cursorSymbolPointSize,
            weight: .bold
        )

        if let pressableKey = key as? KeyboardPressableButton {
            pressableKey.setSymbolConfigurations(
                normal: normalConfiguration,
                highlighted: highlightedConfiguration
            )
        } else {
            key.setPreferredSymbolConfiguration(normalConfiguration, forImageIn: .normal)
            key.setPreferredSymbolConfiguration(highlightedConfiguration, forImageIn: .highlighted)
        }
        applyFunctionKeyBorder(to: key)

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

    private func makeInlineSettingsKey() -> UIButton {
        let key = makeActionSymbolKey(symbolName: "gearshape", action: #selector(inlineSettingsTapped))
        applyFunctionKeyBorder(to: key)

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
            key.setPreferredSymbolConfiguration(highlightedConfiguration, forImageIn: .highlighted)
        }

        key.accessibilityLabel = "Settings"
        key.accessibilityHint = "Shows SweetKeyboard settings."
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

    private func applyFunctionKeyBorder(to key: UIButton) {
        if let pressableKey = key as? KeyboardPressableButton {
            pressableKey.setBorder(
                width: KeyboardMetrics.functionKeyBorderWidth,
                colorProvider: { _ in KeyboardTheme.functionKeyBorderColor }
            )
        } else {
            key.layer.borderWidth = KeyboardMetrics.functionKeyBorderWidth
            key.layer.borderColor = KeyboardTheme.functionKeyBorderColor.resolvedColor(with: key.traitCollection).cgColor
        }
    }

    private func refreshActionKey() {
        let context = ActionKeyInputContext(proxy: textDocumentProxy)
        let isEmailField = context.isEmailField

        if isEmailFieldActive != isEmailField {
            isEmailFieldActive = isEmailField

            if keyboardLayoutMode == .letters {
                rebuildKeyboardRows()
                return
            }
        }

        let model = actionKeyResolver.resolve(for: context)
        guard let actionKeyButton else {
            return
        }

        KeyboardActionKeyRenderer.apply(
            model: model,
            isEnabled: actionKeyResolver.isEnabled(for: model, context: context),
            to: actionKeyButton,
            widthConstraint: actionKeyWidthConstraint
        )
        logActionKeyState(model: model, context: context)
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

    private func copySelectedText() {
        guard displayMode == .clipboard else {
            feedbackPresenter.show("Clipboard mode is off")
            return
        }

        guard let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty else {
            feedbackPresenter.show("No selection")
            return
        }

        UIPasteboard.general.string = selectedText
        clipboardStore.add(text: selectedText, source: .keyboardCopy)
        feedbackPresenter.show("Copied")
    }

    private func pasteFromSystemClipboard() {
        guard displayMode == .clipboard else {
            feedbackPresenter.show("Clipboard mode is off")
            return
        }

        guard let pasteText = UIPasteboard.general.string, !pasteText.isEmpty else {
            feedbackPresenter.show("Nothing to paste")
            return
        }

        textDocumentProxy.insertText(pasteText)
        feedbackPresenter.show("Pasted")
    }

    private func handleClipboardModeChanged(_ isEnabled: Bool) {
        sharedSettingsStore.setClipboardModeEnabled(isEnabled)
        reloadFeatureState(rebuildKeyboard: true)

        if isEnabled {
            feedbackPresenter.show("Clipboard toolbar turned on")
        } else {
            feedbackPresenter.show(
                "Clipboard toolbar turned off. To re-enable it later, open the SweetKeyboard app."
            )
        }
    }

    private func handleInlineSettingsTapped() {
        clearAccentState(rebuild: mode == .keyboard)
        mode = (mode == .settings) ? .keyboard : .settings
    }

    private func returnToLetterKeyboard() {
        keyboardLayoutMode = .letters
        mode = .keyboard
    }

    @objc private func characterKeyTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else {
            return
        }

        let didTriggerAccentReveal = characterHoldController.wasTriggered(on: sender)
        let didHandleTap = characterHoldController.completeTap(on: sender) { [weak self] in
            self?.insertCharacter(title)
        }

        guard !didHandleTap, !didTriggerAccentReveal else {
            return
        }

        insertCharacter(title)
    }

    @objc private func characterKeyTouchDown(_ sender: UIButton) {
        guard
            keyboardLayoutMode == .letters,
            accentState == nil,
            let title = sender.currentTitle,
            AccentCatalog.replacementState(for: title, isUppercase: isShiftActive) != nil
        else {
            characterHoldController.stop()
            return
        }

        characterHoldController.begin(on: sender) { [weak self] in
            self?.revealAccentVariants(for: title)
        }
    }

    @objc private func characterKeyTouchEnded(_ sender: UIButton) {
        _ = sender
        characterHoldController.stop()
    }

    @objc private func shiftTapped() {
        clearAccentState(rebuild: false)
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
        clearAccentState(rebuild: true)
        textDocumentProxy.deleteBackward()
    }

    @objc private func backspaceTouchDown(_ sender: UIButton) {
        backspaceRepeatController.begin(on: sender) { [weak self] in
            self?.backspaceTapped()
        }
    }

    @objc private func backspaceKeyTapped(_ sender: UIButton) {
        backspaceRepeatController.completeTap(on: sender) { [weak self] in
            self?.backspaceTapped()
        }
    }

    @objc private func backspaceTouchEnded(_ sender: UIButton) {
        _ = sender
        backspaceRepeatController.stop()
    }

    @objc private func cursorMovementTouchDown(_ sender: UIButton) {
        cursorRepeatController.begin(on: sender, identifier: sender.tag) { [weak self, offset = sender.tag] in
            self?.moveCursor(by: offset)
        }
    }

    @objc private func cursorMovementKeyTapped(_ sender: UIButton) {
        cursorRepeatController.completeTap(on: sender, identifier: sender.tag) { [weak self, offset = sender.tag] in
            self?.moveCursor(by: offset)
        }
    }

    @objc private func cursorMovementTouchEnded(_ sender: UIButton) {
        _ = sender
        cursorRepeatController.stop()
    }

    @objc private func spaceTapped() {
        clearAccentState(rebuild: true)
        textDocumentProxy.insertText(" ")
    }

    @objc private func actionKeyTapped() {
        clearAccentState(rebuild: true)
        textDocumentProxy.insertText("\n")
    }

    @objc private func symbolKeyboardTapped() {
        clearAccentState(rebuild: false)
        keyboardLayoutMode = .symbols
        rebuildKeyboardRows()
    }

    @objc private func letterKeyboardTapped() {
        clearAccentState(rebuild: false)
        keyboardLayoutMode = .letters
        rebuildKeyboardRows()
    }

    @objc private func inlineSettingsTapped() {
        handleInlineSettingsTapped()
    }

    private func moveCursor(by offset: Int) {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
    }

    private func stopKeyRepeats() {
        characterHoldController.stop()
        cursorRepeatController.stop()
        backspaceRepeatController.stop()
    }

    private var isShiftActive: Bool {
        shiftState != .off
    }

    private func revealAccentVariants(for displayedLetter: String) {
        guard keyboardLayoutMode == .letters else {
            return
        }

        accentState = AccentCatalog.replacementState(
            for: displayedLetter,
            isUppercase: isShiftActive
        )
        rebuildKeyboardRows()
    }

    private func insertCharacter(_ title: String) {
        textDocumentProxy.insertText(title)

        let shouldDisableShift = shiftState == .enabled
        let shouldResetAccentState = accentState != nil

        if shouldDisableShift {
            shiftState = .off
            lastShiftTapAt = nil
        }

        if shouldResetAccentState {
            accentState = nil
        }

        if shouldDisableShift || shouldResetAccentState {
            rebuildKeyboardRows()
        }
    }

    private func clearAccentState(rebuild: Bool) {
        guard accentState != nil else {
            return
        }

        accentState = nil

        if rebuild && keyboardLayoutMode == .letters && mode == .keyboard {
            rebuildKeyboardRows()
        }
    }
}
