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
        case emoji
    }

    private enum DisplayMode {
        case basic
        case clipboard
    }

    private let layoutEngine = KeyboardLayoutEngine()
    private let clipboardStore = ClipboardStore()
    private let actionKeyResolver = ActionKeyResolver()
    private let autoCapitalizationResolver = AutoCapitalizationResolver()
    private let actionKeyDebugStore = ActionKeyDebugStore()
    private let sharedSettingsStore = SharedKeyboardSettingsStore()
    private let capabilityStatusStore = KeyboardCapabilityStatusStore()
    private let shiftStateMachine = KeyboardShiftStateMachine()

    private let shiftDoubleTapInterval: TimeInterval = 0.35
    private let accentHoldDelay: TimeInterval = 0.5
    private let keyRepeatDelay: TimeInterval = 0.8
    private let keyRepeatInterval: TimeInterval = 0.1
    private var shiftState: KeyboardShiftState = .off
    private var lastShiftTapAt: Date?
    private var suppressedAutoCapitalizationContext: AutoCapitalizationContext?
    private var keyboardLayoutMode: KeyboardLayoutMode = .letters {
        didSet {
            refreshModeUI()
        }
    }
    private var isEmailFieldActive = false
    private var accentState: AccentReplacementState?
    private var displayMode: DisplayMode = .basic
    private var sharedSettings = SharedKeyboardSettings()
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
    private let hapticFeedbackController = KeyboardHapticFeedbackController()
    private lazy var backspaceRepeatController = KeyboardKeyRepeatController(
        delay: keyRepeatDelay,
        repeatInterval: keyRepeatInterval
    )
    private lazy var characterHoldController = KeyboardLongPressController(delay: accentHoldDelay)
    private lazy var cursorRepeatController = KeyboardKeyRepeatController(
        delay: keyRepeatDelay,
        repeatInterval: keyRepeatInterval
    )
    private var pressSequenceCoordinator = KeyboardPressSequenceCoordinator()
    private var sequencedKeyKindsByButtonID: [ObjectIdentifier: SequencedKeyKind] = [:]
    private var keyboardRebuildIsDeferred = false

    private weak var actionKeyButton: UIButton?
    private var actionKeyWidthConstraint: NSLayoutConstraint?
    private var inputViewHeightConstraint: NSLayoutConstraint?
    private var keyboardContainerHeightConstraint: NSLayoutConstraint?
    private var keyboardRowsBottomConstraint: NSLayoutConstraint?

    private var desiredClipboardModeEnabled: Bool {
        sharedSettings.clipboardModeEnabled
    }

    private var effectiveDisplayMode: DisplayMode {
        (hasFullAccess && desiredClipboardModeEnabled) ? .clipboard : .basic
    }

    private var shouldShowInlineSettingsKey: Bool {
        displayMode == .basic && keyboardLayoutMode != .letters
    }

    private var currentKeyboardLayoutTarget: SequencedKeyboardLayoutTarget {
        switch keyboardLayoutMode {
        case .letters:
            return .letters
        case .symbols:
            return .symbols
        case .emoji:
            return .emoji
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerTraitObservers()
        bindActions()
        reloadFeatureState(rebuildKeyboard: true)
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
        cancelSequencedInteractions(performDeferredRebuild: false)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshInputContext()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        refreshInputContext()
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
            self.cancelSequencedInteractions()
            self.triggerKeyPressHaptic()

            switch action {
            case .copy:
                copySelectedText()
            case .paste:
                pasteFromSystemClipboard()
            case .clipboard:
                toggleMode(.clipboard)
            case .settings:
                self.handleNonLetterPostAction(.settings, allowsImmediateRebuild: true)
                toggleMode(.settings)
            }
        }

        clipboardPanel.onSelectText = { [weak self] text in
            guard let self else { return }
            self.cancelSequencedInteractions()
            self.triggerKeyPressHaptic()
            self.textDocumentProxy.insertText(text)
            self.feedbackPresenter.show("Inserted")
            self.mode = .keyboard
            self.refreshInputContext(forceKeyboardRebuild: self.keyboardLayoutMode == .letters)
        }

        settingsPanel.onClipboardModeChanged = { [weak self] isEnabled in
            self?.handleClipboardModeChanged(isEnabled)
        }

        settingsPanel.onAutoCapitalizationEnabledChanged = { [weak self] isEnabled in
            self?.handleAutoCapitalizationChanged(isEnabled)
        }

        settingsPanel.onHapticsEnabledChanged = { [weak self] isEnabled in
            self?.handleKeyHapticsChanged(isEnabled)
        }

        settingsPanel.onClose = { [weak self] in
            self?.triggerKeyPressHaptic()
            self?.returnToLetterKeyboard()
        }
    }

    private func reloadFeatureState(rebuildKeyboard: Bool) {
        sharedSettings = sharedSettingsStore.load()
        hapticFeedbackController.setEnabled(sharedSettings.keyHapticsEnabled)

        capabilityStatusStore.setFullAccessEnabled(hasFullAccess)

        let previousDisplayMode = displayMode
        displayMode = effectiveDisplayMode
        actionBar.isHidden = displayMode == .basic

        if displayMode == .basic && mode == .clipboard {
            mode = .keyboard
        }

        updateSettingsPanel()
        updateKeyboardSizingIfNeeded()
        refreshModeUI()
        refreshInputContext(forceKeyboardRebuild: rebuildKeyboard || previousDisplayMode != displayMode)
    }

    private func updateSettingsPanel() {
        let isClipboardToggleEnabled = hasFullAccess

        settingsPanel.render(
            isClipboardModeEnabled: desiredClipboardModeEnabled,
            isAutoCapitalizationEnabled: sharedSettings.autoCapitalizationEnabled,
            isHapticsEnabled: sharedSettings.keyHapticsEnabled,
            isClipboardToggleEnabled: isClipboardToggleEnabled
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

        cancelSequencedInteractions()
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
        pressSequenceCoordinator.cancelAll()
        sequencedKeyKindsByButtonID.removeAll()
        keyboardRebuildIsDeferred = false
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
            rowSpecs = layoutEngine.symbolRows(
                showInlineSettingsKey: shouldShowInlineSettingsKey,
                isSymbolLockEnabled: sharedSettings.symbolLockEnabled
            )
        case .emoji:
            rowSpecs = layoutEngine.emojiRows(
                showInlineSettingsKey: shouldShowInlineSettingsKey,
                isSymbolLockEnabled: sharedSettings.symbolLockEnabled
            )
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

    private func requestKeyboardRebuild(allowsImmediateRebuild: Bool) {
        if allowsImmediateRebuild {
            keyboardRebuildIsDeferred = false
            rebuildKeyboardRows()
            return
        }

        keyboardRebuildIsDeferred = true
    }

    private func performDeferredKeyboardRebuildIfNeeded() {
        guard keyboardRebuildIsDeferred else {
            return
        }

        keyboardRebuildIsDeferred = false
        rebuildKeyboardRows()
    }

    private func cancelSequencedInteractions(performDeferredRebuild: Bool = true) {
        pressSequenceCoordinator.cancelAll()
        characterHoldController.stop()

        if performDeferredRebuild {
            performDeferredKeyboardRebuildIfNeeded()
        } else {
            keyboardRebuildIsDeferred = false
        }
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
        key.addTarget(self, action: #selector(characterKeyTouchUpInside(_:)), for: .touchUpInside)
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
            return makeSpaceKey()
        case .symbolToggle:
            let key = makeActionSymbolKey(symbolName: "command")
            applyFunctionKeyBorder(to: key)
            configureSequencedKey(key, kind: .layoutSwitch(.symbols))
            return key
        case .letterToggle:
            let key = makeActionKey(title: "ABC")
            applyFunctionKeyBorder(to: key)
            configureSequencedKey(key, kind: .layoutSwitch(.letters))
            return key
        case .primaryAction:
            return makePrimaryActionKey()
        case .cursor(let offset, let symbolName):
            return makeCursorMovementKey(symbolName: symbolName, offset: offset)
        case .inlineSettings:
            return makeInlineSettingsKey()
        case .symbolLock(let isEnabled):
            return makeSymbolLockKey(isEnabled: isEnabled)
        case .nonLetterLayoutToggle(let style, let target):
            return makeNonLetterLayoutToggleKey(style: style, target: target)
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

    private func makeActionImageKey(_ image: UIImage?, accessibilityLabel: String) -> UIButton {
        let key = makeBaseKey(title: nil, role: .system)
        if let pressableKey = key as? KeyboardPressableButton {
            pressableKey.setForegroundColors(
                normal: KeyboardTheme.keyLabelColor,
                highlighted: KeyboardTheme.keyLabelColor
            )
            pressableKey.setSymbolImage(image)
        } else {
            let templatedImage = image?.withRenderingMode(.alwaysTemplate)
            key.setImage(templatedImage, for: .normal)
            key.setImage(templatedImage, for: .highlighted)
            key.tintColor = KeyboardTheme.keyLabelColor
        }

        key.accessibilityLabel = accessibilityLabel
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
        case .autoSingle:
            symbolName = "shift.fill"
            accessibilityLabel = "Disable Auto-Capitalization"
        case .manualSingle:
            symbolName = "shift.fill"
            accessibilityLabel = "Disable Shift"
        case .autoPersistent:
            symbolName = "capslock.fill"
            accessibilityLabel = "Disable Auto-Capitalization"
        case .manualLocked:
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
        configureSequencedKey(key, kind: .shift)
        return key
    }

    private func makeSpaceKey() -> UIButton {
        let key = makeCharacterActionKey(title: "")
        configureSequencedKey(key, kind: .text(" "))
        return key
    }

    private func makeCharacterActionKey(title: String) -> UIButton {
        let key = makeBaseKey(title: title, role: .character)
        return key
    }

    private func makePrimaryActionKey() -> UIButton {
        let key = makeBaseKey(title: nil, role: .primaryAction)
        configureSequencedKey(key, kind: .primaryAction)

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

    private func makeSymbolLockKey(isEnabled: Bool) -> UIButton {
        let key = makeActionSymbolKey(
            symbolName: isEnabled ? "lock.fill" : "lock.open",
            action: #selector(symbolLockTapped)
        )
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

        key.accessibilityLabel = isEnabled ? "Keep symbols and emoji open is on" : "Keep symbols and emoji open"
        key.accessibilityHint = "Keeps the symbols and emoji keyboard open so you can type multiple entries."
        return key
    }

    private func makeNonLetterLayoutToggleKey(
        style: NonLetterLayoutToggleStyle,
        target: SequencedKeyboardLayoutTarget
    ) -> UIButton {
        let key: UIButton

        switch style {
        case .emoji:
            key = makeActionImageKey(makeEmojiToggleImage(), accessibilityLabel: "Emoji")
            key.accessibilityHint = "Shows the emoji keyboard."
        case .symbols:
            key = makeActionKey(title: "#+=")
            key.accessibilityLabel = "Symbols"
            key.accessibilityHint = "Returns to the symbols keyboard."
        }

        applyFunctionKeyBorder(to: key)
        configureSequencedKey(key, kind: .layoutSwitch(target))
        return key
    }

    private func makeEmojiToggleImage() -> UIImage? {
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setFillColor(UIColor.black.cgColor)
            cgContext.setLineWidth(1.75)
            cgContext.setLineCap(.round)

            let faceRect = CGRect(x: 4.5, y: 4.5, width: 19, height: 19)
            cgContext.strokeEllipse(in: faceRect)

            let eyeDiameter: CGFloat = 2.3
            let leftEyeRect = CGRect(x: 9.1, y: 10.0, width: eyeDiameter, height: eyeDiameter)
            let rightEyeRect = CGRect(x: 16.6, y: 10.0, width: eyeDiameter, height: eyeDiameter)
            cgContext.fillEllipse(in: leftEyeRect)
            cgContext.fillEllipse(in: rightEyeRect)

            let smilePath = UIBezierPath()
            smilePath.move(to: CGPoint(x: 9.0, y: 16.0))
            smilePath.addQuadCurve(to: CGPoint(x: 19.0, y: 16.0), controlPoint: CGPoint(x: 14.0, y: 20.2))
            smilePath.lineWidth = 1.75
            smilePath.lineCapStyle = .round
            UIColor.black.setStroke()
            smilePath.stroke()
        }.withRenderingMode(.alwaysTemplate)
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

    private func configureSequencedKey(_ button: UIButton, kind: SequencedKeyKind) {
        sequencedKeyKindsByButtonID[ObjectIdentifier(button)] = kind
        button.addTarget(self, action: #selector(sequencedKeyTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(sequencedKeyTouchUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(sequencedKeyTouchEnded(_:)), for: .touchUpOutside)
        button.addTarget(self, action: #selector(sequencedKeyTouchEnded(_:)), for: .touchCancel)
        button.addTarget(self, action: #selector(sequencedKeyTouchEnded(_:)), for: .touchDragExit)
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

    private func refreshInputContext(
        forceKeyboardRebuild: Bool = false,
        allowsImmediateRebuild: Bool = true
    ) {
        let context = ActionKeyInputContext(proxy: textDocumentProxy)
        var shouldRebuildKeyboard = forceKeyboardRebuild

        if isEmailFieldActive != context.isEmailField {
            isEmailFieldActive = context.isEmailField
            shouldRebuildKeyboard = true
        }

        if syncAutoCapitalization(using: context) {
            shouldRebuildKeyboard = true
        }

        updateActionKey(using: context)

        if shouldRebuildKeyboard, mode == .keyboard, keyboardLayoutMode == .letters {
            requestKeyboardRebuild(allowsImmediateRebuild: allowsImmediateRebuild)
        }
    }

    private func refreshActionKey() {
        updateActionKey(using: ActionKeyInputContext(proxy: textDocumentProxy))
    }

    private func updateActionKey(using context: ActionKeyInputContext) {
        let model = actionKeyResolver.resolve(for: context)

        if let actionKeyButton {
            KeyboardActionKeyRenderer.apply(
                model: model,
                isEnabled: actionKeyResolver.isEnabled(for: model, context: context),
                to: actionKeyButton,
                widthConstraint: actionKeyWidthConstraint
            )
        }

        logActionKeyState(model: model, context: context)
    }

    private func syncAutoCapitalization(using context: ActionKeyInputContext) -> Bool {
        let autoCapitalizationContext = context.autoCapitalizationContext(
            isEnabled: sharedSettings.autoCapitalizationEnabled
        )

        if suppressedAutoCapitalizationContext != autoCapitalizationContext {
            suppressedAutoCapitalizationContext = nil
        }

        guard keyboardLayoutMode == .letters else {
            return false
        }

        let newShiftState = shiftStateMachine.applyingAutoCapitalizationDecision(
            autoCapitalizationResolver.resolve(for: autoCapitalizationContext),
            to: shiftState,
            isSuppressed: suppressedAutoCapitalizationContext == autoCapitalizationContext
        )

        guard newShiftState != shiftState else {
            return false
        }

        shiftState = newShiftState
        lastShiftTapAt = nil
        return true
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
        refreshInputContext(forceKeyboardRebuild: keyboardLayoutMode == .letters)
    }

    private func handleClipboardModeChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.clipboardModeEnabled = isEnabled
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

    private func handleKeyHapticsChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.keyHapticsEnabled = isEnabled
        sharedSettingsStore.setKeyHapticsEnabled(isEnabled)
        hapticFeedbackController.setEnabled(isEnabled)

        if isEnabled {
            feedbackPresenter.show("Key haptics turned on")
        } else {
            feedbackPresenter.show("Key haptics turned off")
        }
    }

    private func handleAutoCapitalizationChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.autoCapitalizationEnabled = isEnabled
        sharedSettingsStore.setAutoCapitalizationEnabled(isEnabled)
        refreshInputContext(forceKeyboardRebuild: true)

        if isEnabled {
            feedbackPresenter.show("Auto-capitalization turned on")
        } else {
            feedbackPresenter.show("Auto-capitalization turned off")
        }
    }

    private func handleSymbolLockTapped() {
        sharedSettings.symbolLockEnabled.toggle()
        sharedSettingsStore.setSymbolLockEnabled(sharedSettings.symbolLockEnabled)
        refreshModeUI()
        requestKeyboardRebuild(allowsImmediateRebuild: true)
    }

    private func handleInlineSettingsTapped() {
        cancelSequencedInteractions()
        clearAccentState(rebuild: mode == .keyboard)
        mode = (mode == .settings) ? .keyboard : .settings
    }

    private func returnToLetterKeyboard() {
        cancelSequencedInteractions()
        keyboardLayoutMode = .letters
        mode = .keyboard
        refreshInputContext(forceKeyboardRebuild: true)
    }

    @discardableResult
    private func handleNonLetterPostAction(
        _ action: NonLetterKeyboardPostAction,
        allowsImmediateRebuild: Bool
    ) -> Bool {
        _ = allowsImmediateRebuild
        guard
            keyboardLayoutMode != .letters,
            shouldReturnToLetterKeyboardAfterNonLetterAction(
                action,
                currentLayout: currentKeyboardLayoutTarget,
                isSymbolLockEnabled: sharedSettings.symbolLockEnabled
            )
        else {
            return false
        }

        keyboardLayoutMode = .letters
        return true
    }

    private func triggerKeyPressHaptic() {
        hapticFeedbackController.triggerKeyPress()
    }

    private func beginSequencedTouch(on sender: UIButton, kind: SequencedKeyKind) {
        characterHoldController.stop()
        let keyID = ObjectIdentifier(sender)
        let effects = pressSequenceCoordinator.commitPendingInteractionBeforeTouchDown(id: keyID)
        applySequencedEffects(effects, allowsImmediateRebuild: false)
        pressSequenceCoordinator.beginPendingInteraction(id: keyID, kind: kind)
    }

    private func completeSequencedTouch(on sender: UIButton) {
        let effects = pressSequenceCoordinator.handleTouchUpInside(id: ObjectIdentifier(sender))
        applySequencedEffects(effects, allowsImmediateRebuild: true)
        performDeferredKeyboardRebuildIfNeeded()
    }

    private func cancelSequencedTouch(on sender: UIButton) {
        pressSequenceCoordinator.handleTouchCancelled(id: ObjectIdentifier(sender))
        performDeferredKeyboardRebuildIfNeeded()
    }

    private func applySequencedEffects(_ effects: [SequencedKeyEffect], allowsImmediateRebuild: Bool) {
        for effect in effects {
            switch effect {
            case .insertText(let text):
                if text == " " {
                    insertSpace(allowsImmediateRebuild: allowsImmediateRebuild)
                } else {
                    insertCharacter(text, allowsImmediateRebuild: allowsImmediateRebuild)
                }
            case .toggleShift:
                toggleShift(allowsImmediateRebuild: allowsImmediateRebuild)
            case .setKeyboardLayout(let target):
                setKeyboardLayout(target, allowsImmediateRebuild: allowsImmediateRebuild)
            case .insertPrimaryAction:
                insertPrimaryAction(allowsImmediateRebuild: allowsImmediateRebuild)
            }
        }
    }

    private func resolvedSequencedCharacterText(for displayedTitle: String) -> String {
        guard keyboardLayoutMode == .letters, accentState == nil else {
            return displayedTitle
        }

        return isShiftActive ? displayedTitle.uppercased() : displayedTitle.lowercased()
    }

    @objc private func sequencedKeyTouchDown(_ sender: UIButton) {
        guard let kind = sequencedKeyKindsByButtonID[ObjectIdentifier(sender)] else {
            return
        }

        beginSequencedTouch(on: sender, kind: kind)
    }

    @objc private func sequencedKeyTouchUpInside(_ sender: UIButton) {
        completeSequencedTouch(on: sender)
    }

    @objc private func sequencedKeyTouchEnded(_ sender: UIButton) {
        cancelSequencedTouch(on: sender)
    }

    @objc private func characterKeyTouchUpInside(_ sender: UIButton) {
        guard let title = sender.currentTitle else {
            return
        }

        guard accentState != nil else {
            characterHoldController.stop()
            completeSequencedTouch(on: sender)
            return
        }

        let didTriggerAccentReveal = characterHoldController.wasTriggered(on: sender)
        let didHandleTap = characterHoldController.completeTap(on: sender) { [weak self] in
            self?.insertCharacter(title, allowsImmediateRebuild: true)
        }

        guard !didHandleTap, !didTriggerAccentReveal else {
            return
        }

        insertCharacter(title, allowsImmediateRebuild: true)
    }

    @objc private func characterKeyTouchDown(_ sender: UIButton) {
        guard let displayedTitle = sender.currentTitle else {
            return
        }

        guard accentState == nil else {
            characterHoldController.stop()
            return
        }

        let resolvedTitle = resolvedSequencedCharacterText(for: displayedTitle)
        beginSequencedTouch(on: sender, kind: .text(resolvedTitle))

        guard
            keyboardLayoutMode == .letters,
            AccentCatalog.replacementState(for: resolvedTitle, isUppercase: isShiftActive) != nil
        else {
            return
        }

        characterHoldController.begin(on: sender) { [weak self] in
            self?.revealAccentVariants(for: resolvedTitle)
        }
    }

    @objc private func characterKeyTouchEnded(_ sender: UIButton) {
        characterHoldController.stop()
        guard accentState == nil else {
            return
        }

        cancelSequencedTouch(on: sender)
    }

    private func toggleShift(allowsImmediateRebuild: Bool) {
        triggerKeyPressHaptic()
        let didClearAccentState = clearAccentState(rebuild: false)
        let now = Date()
        let autoCapitalizationContext = ActionKeyInputContext(proxy: textDocumentProxy)
            .autoCapitalizationContext(isEnabled: sharedSettings.autoCapitalizationEnabled)
        let result = shiftStateMachine.toggledState(
            from: shiftState,
            lastShiftTapAt: lastShiftTapAt,
            now: now,
            doubleTapInterval: shiftDoubleTapInterval,
            autoCapitalizationContext: autoCapitalizationContext
        )

        let didShiftStateChange = result.state != shiftState
        shiftState = result.state
        lastShiftTapAt = result.lastShiftTapAt
        suppressedAutoCapitalizationContext = result.suppressedAutoCapitalizationContext

        if didClearAccentState || didShiftStateChange {
            requestKeyboardRebuild(allowsImmediateRebuild: allowsImmediateRebuild)
        }
    }

    private func backspaceTapped(triggerHaptic: Bool) {
        if triggerHaptic {
            triggerKeyPressHaptic()
        }

        let didClearAccentState = clearAccentState(rebuild: false)
        textDocumentProxy.deleteBackward()
        let didReturnToLetters = handleNonLetterPostAction(.backspace, allowsImmediateRebuild: true)
        refreshInputContext(
            forceKeyboardRebuild: didClearAccentState || didReturnToLetters,
            allowsImmediateRebuild: true
        )
    }

    @objc private func backspaceTouchDown(_ sender: UIButton) {
        cancelSequencedInteractions()
        backspaceRepeatController.begin(on: sender) { [weak self] in
            self?.backspaceTapped(triggerHaptic: true)
        }
    }

    @objc private func backspaceKeyTapped(_ sender: UIButton) {
        backspaceRepeatController.completeTap(on: sender) { [weak self] in
            self?.backspaceTapped(triggerHaptic: true)
        }
    }

    @objc private func backspaceTouchEnded(_ sender: UIButton) {
        _ = sender
        backspaceRepeatController.stop()
    }

    @objc private func cursorMovementTouchDown(_ sender: UIButton) {
        cancelSequencedInteractions()
        cursorRepeatController.begin(on: sender, identifier: sender.tag) { [weak self, offset = sender.tag] in
            self?.triggerKeyPressHaptic()
            self?.moveCursor(by: offset)
        }
    }

    @objc private func cursorMovementKeyTapped(_ sender: UIButton) {
        cursorRepeatController.completeTap(on: sender, identifier: sender.tag) { [weak self, offset = sender.tag] in
            self?.triggerKeyPressHaptic()
            self?.moveCursor(by: offset)
        }
    }

    @objc private func cursorMovementTouchEnded(_ sender: UIButton) {
        _ = sender
        cursorRepeatController.stop()
    }

    private func insertSpace(allowsImmediateRebuild: Bool) {
        triggerKeyPressHaptic()
        let didClearAccentState = clearAccentState(rebuild: false)
        textDocumentProxy.insertText(" ")
        let didReturnToLetters = handleNonLetterPostAction(.space, allowsImmediateRebuild: allowsImmediateRebuild)
        refreshInputContext(
            forceKeyboardRebuild: didClearAccentState || didReturnToLetters,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
    }

    private func insertPrimaryAction(allowsImmediateRebuild: Bool) {
        triggerKeyPressHaptic()
        let didClearAccentState = clearAccentState(rebuild: false)
        textDocumentProxy.insertText("\n")
        let didReturnToLetters = handleNonLetterPostAction(.primaryAction, allowsImmediateRebuild: allowsImmediateRebuild)
        refreshInputContext(
            forceKeyboardRebuild: didClearAccentState || didReturnToLetters,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
    }

    private func setKeyboardLayout(_ target: SequencedKeyboardLayoutTarget, allowsImmediateRebuild: Bool) {
        triggerKeyPressHaptic()
        _ = clearAccentState(rebuild: false)

        switch target {
        case .letters:
            keyboardLayoutMode = .letters
            refreshInputContext(
                forceKeyboardRebuild: true,
                allowsImmediateRebuild: allowsImmediateRebuild
            )
        case .symbols:
            keyboardLayoutMode = .symbols
            requestKeyboardRebuild(allowsImmediateRebuild: allowsImmediateRebuild)
        case .emoji:
            keyboardLayoutMode = .emoji
            requestKeyboardRebuild(allowsImmediateRebuild: allowsImmediateRebuild)
        }
    }

    @objc private func inlineSettingsTapped() {
        cancelSequencedInteractions()
        triggerKeyPressHaptic()
        handleNonLetterPostAction(.settings, allowsImmediateRebuild: true)
        handleInlineSettingsTapped()
    }

    @objc private func symbolLockTapped() {
        cancelSequencedInteractions()
        triggerKeyPressHaptic()
        handleSymbolLockTapped()
    }

    private func moveCursor(by offset: Int) {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        let didReturnToLetters = handleNonLetterPostAction(.cursorMovement, allowsImmediateRebuild: true)
        refreshInputContext(forceKeyboardRebuild: didReturnToLetters, allowsImmediateRebuild: true)
    }

    private func stopKeyRepeats() {
        characterHoldController.stop()
        cursorRepeatController.stop()
        backspaceRepeatController.stop()
    }

    private var isShiftActive: Bool {
        shiftState.isActive
    }

    private func revealAccentVariants(for displayedLetter: String) {
        guard keyboardLayoutMode == .letters else {
            return
        }

        pressSequenceCoordinator.cancelAll()
        accentState = AccentCatalog.replacementState(
            for: displayedLetter,
            isUppercase: isShiftActive
        )
        rebuildKeyboardRows()
    }

    private func insertCharacter(_ title: String, allowsImmediateRebuild: Bool) {
        triggerKeyPressHaptic()
        let didClearAccentState = clearAccentState(rebuild: false)
        textDocumentProxy.insertText(title)
        let didReturnToLetters = handleNonLetterPostAction(
            .characterInsertion,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
        let didDisableManualShift = shiftState == .manualSingle

        if didDisableManualShift {
            shiftState = .off
            lastShiftTapAt = nil
        }

        refreshInputContext(
            forceKeyboardRebuild: didClearAccentState || didReturnToLetters || didDisableManualShift,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
    }

    @discardableResult
    private func clearAccentState(rebuild: Bool) -> Bool {
        guard accentState != nil else {
            return false
        }

        accentState = nil

        if rebuild && keyboardLayoutMode == .letters && mode == .keyboard {
            rebuildKeyboardRows()
        }

        return true
    }
}
