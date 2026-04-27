import UIKit

final class KeyboardViewController: UIInputViewController, UIGestureRecognizerDelegate {
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

    private enum DeleteDirection {
        case backward
        case forward
    }

    private let layoutEngine = KeyboardLayoutEngine()
    private let clipboardStore = ClipboardStore()
    private let clipboardCopyService = ClipboardCopyService()
    private let clipboardSystemImportService = ClipboardSystemImportService()
    private let actionKeyResolver = ActionKeyResolver()
    private let autoCapitalizationResolver = AutoCapitalizationResolver()
    private let sharedSettingsStore = SharedKeyboardSettingsStore()
    private let capabilityStatusStore = KeyboardCapabilityStatusStore(localFallbackDefaults: .standard)
    private let shiftStateMachine = KeyboardShiftStateMachine()

    private let shiftDoubleTapInterval: TimeInterval = 0.35
    private let accentHoldDelay: TimeInterval = 0.25
    private let keyRepeatDelay: TimeInterval = 0.25
    private let keyRepeatInterval: TimeInterval = 0.1
    private let cursorSwipeBasePointsPerCharacter: CGFloat = 18
    private let cursorSwipeFastPointsPerCharacter: CGFloat = 13
    private let cursorSwipeVeryFastPointsPerCharacter: CGFloat = 5
    private let cursorSwipeFastVelocityThreshold: CGFloat = 900
    private let cursorSwipeVeryFastVelocityThreshold: CGFloat = 1_600
    private let cursorSwipeMaximumCharactersPerUpdate = 8
    private let cursorSwipeVeryFastMaximumCharactersPerUpdate = 24
    private let cursorSwipeHorizontalDominanceRatio: CGFloat = 1.4
    private var shiftState: KeyboardShiftState = .off
    private var lastShiftTapAt: Date?
    private var suppressedAutoCapitalizationContext: AutoCapitalizationContext?
    private var cursorSwipeResidualTranslation: CGFloat = 0
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
    private lazy var cursorSwipeGestureRecognizer: UIPanGestureRecognizer = {
        let gestureRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(cursorSwipeGestureChanged(_:))
        )
        gestureRecognizer.cancelsTouchesInView = false
        gestureRecognizer.minimumNumberOfTouches = 1
        gestureRecognizer.maximumNumberOfTouches = 1
        gestureRecognizer.delegate = self
        return gestureRecognizer
    }()
    private var pressSequenceCoordinator = KeyboardPressSequenceCoordinator()
    private var sequencedKeyKindsByButtonID: [ObjectIdentifier: SequencedKeyKind] = [:]
    private var keyboardRebuildIsDeferred = false
    private var activeDeleteDirection: DeleteDirection?
    private var pasteboardChangeObserver: NSObjectProtocol?
    private var clipboardImportPollTimer: Timer?
    private var clipboardImportPollsRemaining = 0

    private weak var actionKeyButton: UIButton?
    private weak var actionKeyHitTarget: KeyboardHitTargetButton?
    private weak var lastKeyboardRowView: KeyboardInteractiveRowView?
    private var actionKeyWidthConstraint: NSLayoutConstraint?
    private var inputViewHeightConstraint: NSLayoutConstraint?
    private var keyboardContainerHeightConstraint: NSLayoutConstraint?
    private var keyboardRowsBottomConstraint: NSLayoutConstraint?

    private var desiredClipboardModeEnabled: Bool {
        sharedSettings.clipboardModeEnabled
    }

    private var canCheckSystemClipboardImport: Bool {
        hasFullAccess && sharedSettings.clipboardModeEnabled
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
        beginClipboardImportAvailabilitySessionIfAllowed()
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
        stopClipboardImportAvailabilityMonitoring()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshInputContext(allowsImmediateRebuild: activeDeleteDirection == nil)
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        refreshInputContext(allowsImmediateRebuild: activeDeleteDirection == nil)
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
        keyboardRows.spacing = 0

        actionBar.setContentHuggingPriority(.required, for: .vertical)
        actionBar.setContentCompressionResistancePriority(.required, for: .vertical)
        keyboardContainer.setContentHuggingPriority(.required, for: .vertical)
        keyboardContainer.setContentCompressionResistancePriority(.required, for: .vertical)

        keyboardContainer.addSubview(keyboardRows)
        keyboardContainer.addSubview(clipboardPanel)
        keyboardContainer.addSubview(settingsPanel)
        keyboardRows.addGestureRecognizer(cursorSwipeGestureRecognizer)

        keyboardRows.translatesAutoresizingMaskIntoConstraints = false
        clipboardPanel.translatesAutoresizingMaskIntoConstraints = false
        settingsPanel.translatesAutoresizingMaskIntoConstraints = false

        keyboardRowsBottomConstraint = keyboardRows.bottomAnchor.constraint(
            equalTo: keyboardContainer.bottomAnchor,
            constant: 0
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
        actionBar.onPressDown = { [weak self] in
            self?.triggerKeyPressHaptic()
        }

        actionBar.onAction = { [weak self] action in
            guard let self else { return }
            self.cancelSequencedInteractions()

            switch action {
            case .copy:
                copySelectedText()
            case .importClipboard:
                importSystemClipboardFromUserAction()
            case .clipboard:
                toggleMode(.clipboard)
            case .settings:
                self.handleNonLetterPostAction(.settings, allowsImmediateRebuild: true)
                toggleMode(.settings)
            case .hideKeyboard:
                dismissKeyboard()
            }
        }

        clipboardPanel.onPressDown = { [weak self] in
            self?.triggerKeyPressHaptic()
        }

        clipboardPanel.onSelectText = { [weak self] text in
            guard let self else { return }
            self.cancelSequencedInteractions()
            self.textDocumentProxy.insertText(text)
            self.mode = .keyboard
            self.refreshInputContext(forceKeyboardRebuild: self.keyboardLayoutMode == .letters)
        }

        clipboardPanel.onOpenDetail = { [weak self] in
            self?.triggerKeyPressHaptic()
        }

        clipboardPanel.onCloseDetail = { [weak self] in
            guard let self else { return }
            self.refreshClipboardPanelIfVisible()
        }

        clipboardPanel.onTogglePin = { [weak self] item in
            guard let self else { return item }
            self.cancelSequencedInteractions()

            let shouldPin = !item.isPinned
            guard self.clipboardStore.setPinned(id: item.id, isPinned: shouldPin),
                  let updatedItem = self.clipboardStore.allItems().first(where: { $0.id == item.id }) else {
                return item
            }

            return updatedItem
        }

        clipboardPanel.onDeleteItem = { [weak self] item in
            guard let self else { return }
            self.cancelSequencedInteractions()

            _ = self.clipboardStore.delete(id: item.id)

            self.showClipboardPanel()
        }

        settingsPanel.onClipboardModeChanged = { [weak self] isEnabled in
            self?.handleClipboardModeChanged(isEnabled)
        }

        settingsPanel.onOpenClipboardAfterCopyChanged = { [weak self] isEnabled in
            self?.handleOpenClipboardAfterCopyChanged(isEnabled)
        }

        settingsPanel.onAutoCapitalizationEnabledChanged = { [weak self] isEnabled in
            self?.handleAutoCapitalizationChanged(isEnabled)
        }

        settingsPanel.onForwardDeleteWithShiftChanged = { [weak self] isEnabled in
            self?.handleForwardDeleteWithShiftChanged(isEnabled)
        }

        settingsPanel.onCursorSwipeEnabledChanged = { [weak self] isEnabled in
            self?.handleCursorSwipeEnabledChanged(isEnabled)
        }

        settingsPanel.onHapticsEnabledChanged = { [weak self] isEnabled in
            self?.handleKeyHapticsChanged(isEnabled)
        }

        settingsPanel.onPressDown = { [weak self] in
            self?.triggerKeyPressHaptic()
        }

        settingsPanel.onClose = { [weak self] in
            self?.returnToLetterKeyboard()
        }
    }

    private func reloadFeatureState(rebuildKeyboard: Bool) {
        sharedSettings = sharedSettingsStore.load()
        hapticFeedbackController.setEnabled(sharedSettings.keyHapticsEnabled)

        if hasFullAccess {
            capabilityStatusStore.confirmFullAccessNow()
        }

        let capabilityStatus = capabilityStatusStore.load()

        let previousDisplayMode = displayMode
        displayMode = effectiveDisplayMode
        actionBar.isHidden = displayMode == .basic

        if displayMode == .basic && mode == .clipboard {
            mode = .keyboard
        }

        updateSettingsPanel(capabilityStatus: capabilityStatus)
        updateKeyboardSizingIfNeeded()
        refreshModeUI()
        refreshInputContext(forceKeyboardRebuild: rebuildKeyboard || previousDisplayMode != displayMode)
        refreshClipboardImportAvailabilityObservation()
    }

    private func updateSettingsPanel(capabilityStatus: KeyboardCapabilityStatus) {
        settingsPanel.render(
            isClipboardModeEnabled: desiredClipboardModeEnabled,
            isOpenClipboardAfterCopyEnabled: sharedSettings.openClipboardAfterCopyEnabled,
            isAutoCapitalizationEnabled: sharedSettings.autoCapitalizationEnabled,
            isCursorSwipeEnabled: sharedSettings.cursorSwipeEnabled,
            isForwardDeleteWithShiftEnabled: sharedSettings.forwardDeleteWithShiftEnabled,
            isHapticsEnabled: sharedSettings.keyHapticsEnabled,
            fullAccessStatusText: KeyboardCapabilityStatusTextFormatter.keyboardSettingsSummary(
                isFullAccessCurrentlyAvailable: hasFullAccess,
                status: capabilityStatus,
                isClipboardModeEnabled: desiredClipboardModeEnabled
            )
        )
    }

    private func applyTheme() {
        view.backgroundColor = KeyboardTheme.keyboardBackground
        keyboardContainer.backgroundColor = .clear
    }

    private func toggleMode(_ targetMode: Mode) {
        if targetMode == .clipboard && displayMode != .clipboard {
            return
        }

        cancelSequencedInteractions()
        clearAccentState(rebuild: mode == .keyboard)
        mode = (mode == targetMode) ? .keyboard : targetMode

        if mode == .clipboard {
            updateClipboardImportAvailability()
        }
    }

    private func refreshModeUI() {
        let isClipboardVisible = displayMode == .clipboard && mode == .clipboard

        keyboardRows.isHidden = mode != .keyboard
        clipboardPanel.isHidden = !isClipboardVisible
        settingsPanel.isHidden = mode != .settings

        actionBar.setClipboardActive(isClipboardVisible)
        actionBar.setSettingsActive(displayMode == .clipboard && mode == .settings)

        if isClipboardVisible {
            updateClipboardImportAvailability()
            clipboardPanel.render(items: clipboardStore.allItems())
        }
    }

    private func rebuildKeyboardRows() {
        stopKeyRepeats()
        pressSequenceCoordinator.cancelAll()
        sequencedKeyKindsByButtonID.removeAll()
        keyboardRebuildIsDeferred = false
        actionKeyButton = nil
        actionKeyHitTarget = nil
        actionKeyWidthConstraint = nil
        lastKeyboardRowView = nil
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

        let bottomInset = KeyboardMetrics.keyboardBottomInset(for: view.safeAreaInsets)

        for (index, rowSpec) in rowSpecs.enumerated() {
            let rowView = makeRow(
                from: rowSpec,
                rowIndex: index,
                rowCount: rowSpecs.count,
                bottomInset: bottomInset
            )
            if index == (rowSpecs.count - 1) {
                lastKeyboardRowView = rowView
            }
            keyboardRows.addArrangedSubview(rowView)
        }

        refreshActionKey()
    }

    private func makeRow(
        from spec: KeyboardRowSpec,
        rowIndex: Int,
        rowCount: Int,
        bottomInset: CGFloat
    ) -> KeyboardInteractiveRowView {
        let rowInsets = KeyboardTouchLayoutCalculator.rowInsets(
            rowIndex: rowIndex,
            rowCount: rowCount,
            visualRowSpacing: KeyboardMetrics.keyboardVisualRowSpacing,
            bottomInset: bottomInset
        )
        let row = KeyboardInteractiveRowView(
            topInset: rowInsets.top,
            bottomInset: rowInsets.bottom,
            keyHeight: KeyboardMetrics.keyboardRowHeight,
            visualRowSpacing: KeyboardMetrics.keyboardVisualRowSpacing
        )

        guard let firstItem = spec.items.first else {
            return row
        }

        let referenceButton = makeKey(for: firstItem.kind)
        sequencedKeyKindsByButtonID.removeValue(forKey: ObjectIdentifier(referenceButton))
        let referenceHitTarget = makeHitTarget(for: firstItem.kind, visualButton: referenceButton)
        row.addKey(visualButton: referenceButton, hitTarget: referenceHitTarget)
        let referenceMinimumWidthConstraint = referenceButton.widthAnchor.constraint(
            greaterThanOrEqualToConstant: KeyboardMetrics.keyUnitWidth * firstItem.width.minimumUnits
        )
        referenceMinimumWidthConstraint.isActive = true

        if case .primaryAction = firstItem.kind {
            actionKeyButton = referenceButton
            actionKeyHitTarget = referenceHitTarget
            actionKeyWidthConstraint = referenceMinimumWidthConstraint
        }

        let referenceShare = max(firstItem.width.share, 0.001)

        for item in spec.items.dropFirst() {
            let button = makeKey(for: item.kind)
            sequencedKeyKindsByButtonID.removeValue(forKey: ObjectIdentifier(button))
            let hitTarget = makeHitTarget(for: item.kind, visualButton: button)
            row.addKey(visualButton: button, hitTarget: hitTarget)

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
                actionKeyHitTarget = hitTarget
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

        lastKeyboardRowView?.setBottomInset(bottomInset)

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
            return makeDeleteKey()
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
        if let action {
            key.addTarget(self, action: action, for: .touchUpInside)
        }
        return key
    }

    private func makeDeleteKey() -> UIButton {
        let usesForwardDelete = isForwardDeleteActive
        let key = makeBaseKey(title: usesForwardDelete ? "⌦" : "⌫", role: .system)
        applyFunctionKeyBorder(to: key)
        key.accessibilityLabel = usesForwardDelete ? "Forward Delete" : "Delete"

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
        let key = makeActionSymbolKey(symbolName: "gearshape.fill", action: #selector(inlineSettingsTapped))
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
        button.isUserInteractionEnabled = false
        button.isAccessibilityElement = false
        return button
    }

    private func makeHitTarget(for kind: KeyboardKeyKind, visualButton: UIButton) -> KeyboardHitTargetButton {
        let hitTarget = KeyboardHitTargetButton(type: .custom)
        hitTarget.visualButton = visualButton

        switch kind {
        case .character:
            hitTarget.addTarget(self, action: #selector(characterKeyTouchDown(_:)), for: .touchDown)
            hitTarget.addTarget(self, action: #selector(characterKeyTouchUpInside(_:)), for: .touchUpInside)
            hitTarget.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: .touchUpOutside)
            hitTarget.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: .touchCancel)
            hitTarget.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: .touchDragExit)
        case .shift:
            configureSequencedKey(hitTarget, kind: .shift)
        case .backspace:
            hitTarget.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
            hitTarget.addTarget(self, action: #selector(backspaceKeyTapped(_:)), for: .touchUpInside)
            hitTarget.addTarget(self, action: #selector(backspaceTouchEnded(_:)), for: .touchUpOutside)
            hitTarget.addTarget(self, action: #selector(backspaceTouchEnded(_:)), for: .touchCancel)
            hitTarget.addTarget(self, action: #selector(backspaceTouchEnded(_:)), for: .touchDragExit)
        case .space:
            configureSequencedKey(hitTarget, kind: .text(" "))
        case .symbolToggle:
            configureSequencedKey(hitTarget, kind: .layoutSwitch(.symbols))
        case .letterToggle:
            configureSequencedKey(hitTarget, kind: .layoutSwitch(.letters))
        case .primaryAction:
            configureSequencedKey(hitTarget, kind: .primaryAction)
        case .cursor(let offset, _):
            hitTarget.tag = offset
            hitTarget.addTarget(self, action: #selector(cursorMovementTouchDown(_:)), for: .touchDown)
            hitTarget.addTarget(self, action: #selector(cursorMovementKeyTapped(_:)), for: .touchUpInside)
            hitTarget.addTarget(self, action: #selector(cursorMovementTouchEnded(_:)), for: .touchUpOutside)
            hitTarget.addTarget(self, action: #selector(cursorMovementTouchEnded(_:)), for: .touchCancel)
            hitTarget.addTarget(self, action: #selector(cursorMovementTouchEnded(_:)), for: .touchDragExit)
        case .inlineSettings:
            hitTarget.addTarget(self, action: #selector(keyTouchDownHaptic), for: .touchDown)
            hitTarget.addTarget(self, action: #selector(inlineSettingsTapped), for: .touchUpInside)
        case .symbolLock:
            hitTarget.addTarget(self, action: #selector(keyTouchDownHaptic), for: .touchDown)
            hitTarget.addTarget(self, action: #selector(symbolLockTapped), for: .touchUpInside)
        case .nonLetterLayoutToggle(_, let target):
            configureSequencedKey(hitTarget, kind: .layoutSwitch(target))
        }

        return hitTarget
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
            actionKeyHitTarget?.syncFromVisualButton()
        }
    }

    private func copySelectedText() {
        guard displayMode == .clipboard else {
            return
        }

        let selectedText: String?
        if clipboardPanel.isShowingDetail {
            selectedText = clipboardPanel.selectedTextForCopyAction()
        } else {
            selectedText = textDocumentProxy.selectedText
        }

        guard let selectedText, !selectedText.isEmpty else {
            return
        }

        guard clipboardCopyService.copySelectedText(selectedText, to: UIPasteboard.general) else {
            return
        }

        clipboardStore.add(text: selectedText, source: .keyboardCopy)
        clipboardSystemImportService.markProcessed(UIPasteboard.general)
        updateClipboardImportAvailability()

        if sharedSettings.openClipboardAfterCopyEnabled {
            showClipboardPanel()
        } else {
            refreshClipboardPanelIfVisible()
        }

    }

    private func beginClipboardImportAvailabilitySessionIfAllowed() {
        guard canCheckSystemClipboardImport else {
            stopClipboardImportAvailabilityMonitoring()
            return
        }

        refreshClipboardImportAvailabilityObservation()
        updateClipboardImportAvailability()
        startClipboardImportAvailabilityPollingWindowIfAllowed()
    }

    private func refreshClipboardImportAvailabilityObservation() {
        guard canCheckSystemClipboardImport else {
            stopClipboardImportAvailabilityMonitoring()
            return
        }

        guard pasteboardChangeObserver == nil else {
            return
        }

        pasteboardChangeObserver = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateClipboardImportAvailability()
        }
    }

    private func startClipboardImportAvailabilityPollingWindowIfAllowed() {
        guard canCheckSystemClipboardImport else {
            clipboardImportPollTimer?.invalidate()
            clipboardImportPollTimer = nil
            return
        }

        clipboardImportPollTimer?.invalidate()
        clipboardImportPollsRemaining = 3

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.updateClipboardImportAvailability()
            self.clipboardImportPollsRemaining -= 1

            if self.clipboardImportPollsRemaining <= 0 {
                timer.invalidate()
                self.clipboardImportPollTimer = nil
            }
        }

        clipboardImportPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopClipboardImportAvailabilityMonitoring() {
        if let pasteboardChangeObserver {
            NotificationCenter.default.removeObserver(pasteboardChangeObserver)
            self.pasteboardChangeObserver = nil
        }

        clipboardImportPollTimer?.invalidate()
        clipboardImportPollTimer = nil
        clipboardImportPollsRemaining = 0
        actionBar.setClipboardImportAvailable(false)
    }

    private func updateClipboardImportAvailability() {
        let isAvailable = clipboardSystemImportService.hasAvailableText(
            in: UIPasteboard.general,
            context: ClipboardSystemImportContext(
                isFullAccessAvailable: hasFullAccess,
                isClipboardModeEnabled: sharedSettings.clipboardModeEnabled
            )
        )

        actionBar.setClipboardImportAvailable(displayMode == .clipboard && isAvailable)
    }

    private func importSystemClipboardFromUserAction() {
        let result = clipboardSystemImportService.importAvailableText(
            from: UIPasteboard.general,
            into: clipboardStore,
            context: ClipboardSystemImportContext(
                isFullAccessAvailable: hasFullAccess,
                isClipboardModeEnabled: sharedSettings.clipboardModeEnabled
            )
        )

        updateClipboardImportAvailability()

        switch result {
        case .stored:
            showClipboardPanel()
        case .duplicate:
            showClipboardPanel()
        case .unavailable:
            break
        case .alreadyProcessed, .noText, .emptyText:
            break
        }
    }

    private func showClipboardPanel() {
        guard displayMode == .clipboard else {
            return
        }

        mode = .clipboard
        clipboardPanel.render(items: clipboardStore.allItems())
    }

    private func refreshClipboardPanelIfVisible() {
        guard displayMode == .clipboard, mode == .clipboard else {
            return
        }

        clipboardPanel.render(items: clipboardStore.allItems())
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

    private func handleClipboardModeChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.clipboardModeEnabled = isEnabled
        sharedSettingsStore.setClipboardModeEnabled(isEnabled)
        reloadFeatureState(rebuildKeyboard: true)

        if canCheckSystemClipboardImport {
            updateClipboardImportAvailability()
            startClipboardImportAvailabilityPollingWindowIfAllowed()
        }

    }

    private func handleKeyHapticsChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.keyHapticsEnabled = isEnabled
        sharedSettingsStore.setKeyHapticsEnabled(isEnabled)
        hapticFeedbackController.setEnabled(isEnabled)

    }

    private func handleOpenClipboardAfterCopyChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.openClipboardAfterCopyEnabled = isEnabled
        sharedSettingsStore.setOpenClipboardAfterCopyEnabled(isEnabled)

    }

    private func handleAutoCapitalizationChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.autoCapitalizationEnabled = isEnabled
        sharedSettingsStore.setAutoCapitalizationEnabled(isEnabled)
        refreshInputContext(forceKeyboardRebuild: true)

    }

    private func handleForwardDeleteWithShiftChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        let wasForwardDeleteActive = isForwardDeleteActive
        sharedSettings.forwardDeleteWithShiftEnabled = isEnabled
        sharedSettingsStore.setForwardDeleteWithShiftEnabled(isEnabled)

        if wasForwardDeleteActive != isForwardDeleteActive {
            requestKeyboardRebuild(allowsImmediateRebuild: true)
        }

    }

    private func handleCursorSwipeEnabledChanged(_ isEnabled: Bool) {
        cancelSequencedInteractions()
        sharedSettings.cursorSwipeEnabled = isEnabled
        sharedSettingsStore.setCursorSwipeEnabled(isEnabled)
        resetCursorSwipeState()

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
        triggerKeyPressHaptic()
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
            triggerKeyPressHaptic()
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

    @objc private func keyTouchDownHaptic() {
        triggerKeyPressHaptic()
    }

    private func toggleShift(allowsImmediateRebuild: Bool) {
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

    @discardableResult
    private func backspaceTapped(
        direction: DeleteDirection,
        triggerHaptic: Bool,
        allowsImmediateRebuild: Bool
    ) -> Bool {
        guard direction == .backward || canPerformForwardDelete else {
            return false
        }

        if triggerHaptic {
            triggerKeyPressHaptic()
        }

        let didClearAccentState = clearAccentState(rebuild: false)
        performDelete(direction: direction)
        let didReturnToLetters = handleNonLetterPostAction(
            .backspace,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
        refreshInputContext(
            forceKeyboardRebuild: didClearAccentState || didReturnToLetters,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
        return true
    }

    private var canPerformForwardDelete: Bool {
        if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
            return true
        }

        return !(textDocumentProxy.documentContextAfterInput?.isEmpty ?? true)
    }

    private func performDelete(direction: DeleteDirection) {
        switch direction {
        case .backward:
            textDocumentProxy.deleteBackward()
            return
        case .forward:
            if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
                textDocumentProxy.deleteBackward()
                return
            }

            textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            textDocumentProxy.deleteBackward()
        }
    }

    @objc private func backspaceTouchDown(_ sender: UIButton) {
        cancelSequencedInteractions()
        let direction: DeleteDirection = isForwardDeleteActive ? .forward : .backward
        activeDeleteDirection = direction
        backspaceRepeatController.begin(on: sender) { [weak self] in
            guard let self else {
                return
            }

            guard self.backspaceTapped(
                direction: direction,
                triggerHaptic: true,
                allowsImmediateRebuild: false
            ) else {
                self.finishBackspacePress()
                return
            }
        }

        guard backspaceTapped(
            direction: direction,
            triggerHaptic: true,
            allowsImmediateRebuild: false
        ) else {
            finishBackspacePress()
            return
        }
    }

    @objc private func backspaceKeyTapped(_ sender: UIButton) {
        _ = sender
        finishBackspacePress()
    }

    @objc private func backspaceTouchEnded(_ sender: UIButton) {
        _ = sender
        finishBackspacePress()
    }

    private func finishBackspacePress() {
        backspaceRepeatController.stop()
        activeDeleteDirection = nil
        performDeferredKeyboardRebuildIfNeeded()
    }

    @objc private func cursorMovementTouchDown(_ sender: UIButton) {
        cancelSequencedInteractions()
        triggerKeyPressHaptic()
        cursorRepeatController.begin(on: sender, identifier: sender.tag) { [weak self, offset = sender.tag] in
            self?.triggerKeyPressHaptic()
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

    private func insertSpace(allowsImmediateRebuild: Bool) {
        let didClearAccentState = clearAccentState(rebuild: false)
        textDocumentProxy.insertText(" ")
        let didReturnToLetters = handleNonLetterPostAction(.space, allowsImmediateRebuild: allowsImmediateRebuild)
        refreshInputContext(
            forceKeyboardRebuild: didClearAccentState || didReturnToLetters,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
    }

    private func insertPrimaryAction(allowsImmediateRebuild: Bool) {
        let didClearAccentState = clearAccentState(rebuild: false)
        textDocumentProxy.insertText("\n")
        let didReturnToLetters = handleNonLetterPostAction(.primaryAction, allowsImmediateRebuild: allowsImmediateRebuild)
        refreshInputContext(
            forceKeyboardRebuild: didClearAccentState || didReturnToLetters,
            allowsImmediateRebuild: allowsImmediateRebuild
        )
    }

    private func setKeyboardLayout(_ target: SequencedKeyboardLayoutTarget, allowsImmediateRebuild: Bool) {
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
        handleNonLetterPostAction(.settings, allowsImmediateRebuild: true)
        handleInlineSettingsTapped()
    }

    @objc private func symbolLockTapped() {
        cancelSequencedInteractions()
        handleSymbolLockTapped()
    }

    private func moveCursor(by offset: Int) {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        let didReturnToLetters = handleNonLetterPostAction(.cursorMovement, allowsImmediateRebuild: true)
        refreshInputContext(forceKeyboardRebuild: didReturnToLetters, allowsImmediateRebuild: true)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === cursorSwipeGestureRecognizer else {
            return true
        }

        guard
            sharedSettings.cursorSwipeEnabled,
            mode == .keyboard,
            !keyboardRows.isHidden
        else {
            return false
        }

        let velocity = cursorSwipeGestureRecognizer.velocity(in: keyboardRows)
        return abs(velocity.x) > abs(velocity.y) * cursorSwipeHorizontalDominanceRatio
    }

    @objc private func cursorSwipeGestureChanged(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            cancelSequencedInteractions()
            stopKeyRepeats()
            _ = clearAccentState(rebuild: true)
            resetCursorSwipeState()
            gestureRecognizer.setTranslation(.zero, in: keyboardRows)
        case .changed:
            handleCursorSwipeChanged(gestureRecognizer)
        case .ended, .cancelled, .failed:
            resetCursorSwipeState()
        default:
            break
        }
    }

    private func handleCursorSwipeChanged(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard
            sharedSettings.cursorSwipeEnabled,
            mode == .keyboard,
            !keyboardRows.isHidden
        else {
            resetCursorSwipeState()
            return
        }

        let translation = gestureRecognizer.translation(in: keyboardRows)
        cursorSwipeResidualTranslation += translation.x
        gestureRecognizer.setTranslation(.zero, in: keyboardRows)

        let velocityX = gestureRecognizer.velocity(in: keyboardRows).x
        let pointsPerCharacter = cursorSwipePointsPerCharacter(forVelocityX: velocityX)
        var offset = Int(cursorSwipeResidualTranslation / pointsPerCharacter)
        guard offset != 0 else {
            return
        }

        let maximumCharactersPerUpdate = cursorSwipeMaximumCharactersPerUpdate(forVelocityX: velocityX)
        offset = min(max(offset, -maximumCharactersPerUpdate), maximumCharactersPerUpdate)
        cursorSwipeResidualTranslation -= CGFloat(offset) * pointsPerCharacter
        moveCursor(by: offset)
    }

    private func cursorSwipePointsPerCharacter(forVelocityX velocityX: CGFloat) -> CGFloat {
        let absoluteVelocity = abs(velocityX)
        if absoluteVelocity >= cursorSwipeVeryFastVelocityThreshold {
            return cursorSwipeVeryFastPointsPerCharacter
        }

        if absoluteVelocity >= cursorSwipeFastVelocityThreshold {
            return cursorSwipeFastPointsPerCharacter
        }

        return cursorSwipeBasePointsPerCharacter
    }

    private func cursorSwipeMaximumCharactersPerUpdate(forVelocityX velocityX: CGFloat) -> Int {
        if abs(velocityX) >= cursorSwipeVeryFastVelocityThreshold {
            return cursorSwipeVeryFastMaximumCharactersPerUpdate
        }

        return cursorSwipeMaximumCharactersPerUpdate
    }

    private func resetCursorSwipeState() {
        cursorSwipeResidualTranslation = 0
    }

    private func stopKeyRepeats() {
        characterHoldController.stop()
        cursorRepeatController.stop()
        backspaceRepeatController.stop()
        activeDeleteDirection = nil
    }

    private var isShiftActive: Bool {
        shiftState.isActive
    }

    private var isForwardDeleteActive: Bool {
        shiftStateMachine.shouldUseForwardDelete(
            shiftState: shiftState,
            isForwardDeleteWithShiftEnabled: sharedSettings.forwardDeleteWithShiftEnabled
        )
    }

    private func revealAccentVariants(for displayedLetter: String) {
        guard keyboardLayoutMode == .letters else {
            return
        }

        guard let replacementState = AccentCatalog.replacementState(
            for: displayedLetter,
            isUppercase: isShiftActive
        ) else {
            return
        }

        pressSequenceCoordinator.cancelAll()
        accentState = replacementState
        triggerKeyPressHaptic()
        rebuildKeyboardRows()
    }

    private func insertCharacter(_ title: String, allowsImmediateRebuild: Bool) {
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

extension UIPasteboard: ClipboardReadablePasteboard, ClipboardTextPasteboard {}
