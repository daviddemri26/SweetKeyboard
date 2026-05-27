import UIKit

final class KeyboardSettingsPanelView: UIView {
    var onClipboardModeChanged: ((Bool) -> Void)?
    var onOpenClipboardAfterCopyChanged: ((Bool) -> Void)?
    var onSystemClipboardActionModeChanged: ((SystemClipboardActionMode) -> Void)?
    var onAutoCapitalizationEnabledChanged: ((Bool) -> Void)?
    var onCursorSwipeEnabledChanged: ((Bool) -> Void)?
    var onForwardDeleteWithShiftChanged: ((Bool) -> Void)?
    var onHapticsEnabledChanged: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    var onPressDown: (() -> Void)?

    private enum Constants {
        static let chromeSpacing: CGFloat = 8
        static let contentTopInset: CGFloat = 6
        static let contentHorizontalInset: CGFloat = 12
        static let contentBottomInset: CGFloat = 8
        static let cardSpacing: CGFloat = 10
        static let rowMinHeight: CGFloat = 50
        static let rowHorizontalInset: CGFloat = 16
        static let rowSpacing: CGFloat = 12
        static let cardCornerRadius: CGFloat = 16
        static let modeButtonMinWidth: CGFloat = 132
        static let modeButtonHeight: CGFloat = 34
    }

    private let contentStack = UIStackView()
    private let chromeStack = UIStackView()
    private let closeButton = KeyboardPressableButton(type: .custom)
    private let scrollView = UIScrollView()
    private let scrollContentStack = UIStackView()

    private let clipboardToolsCard = UIView()
    private let clipboardToolsCardStack = UIStackView()
    private let generalCard = UIView()
    private let generalCardStack = UIStackView()

    private let clipboardRow = UIStackView()
    private let clipboardTitleLabel = UILabel()
    private let clipboardSwitch = UISwitch()
    private let clipboardInfoRow = UIView()
    private let clipboardInfoLabel = UILabel()
    private let clipboardSeparator = UIView()

    private let systemClipboardActionModeRow = UIStackView()
    private let systemClipboardActionModeTitleLabel = UILabel()
    private let systemClipboardActionModeButton = KeyboardPressableButton(type: .custom)
    private let systemClipboardActionModeHelperRow = UIView()
    private let systemClipboardActionModeHelperLabel = UILabel()
    private let systemClipboardActionModeSeparator = UIView()

    private let openClipboardAfterCopyRow = UIStackView()
    private let openClipboardAfterCopyTitleLabel = UILabel()
    private let openClipboardAfterCopySwitch = UISwitch()

    private let hapticsRow = UIStackView()
    private let hapticsTitleLabel = UILabel()
    private let hapticsSwitch = UISwitch()
    private let hapticsSeparator = UIView()

    private let autoCapitalizationRow = UIStackView()
    private let autoCapitalizationTitleLabel = UILabel()
    private let autoCapitalizationSwitch = UISwitch()
    private let autoCapitalizationSeparator = UIView()

    private let forwardDeleteWithShiftRow = UIStackView()
    private let forwardDeleteWithShiftTitleLabel = UILabel()
    private let forwardDeleteWithShiftSwitch = UISwitch()
    private let forwardDeleteWithShiftSeparator = UIView()

    private let cursorSwipeRow = UIStackView()
    private let cursorSwipeTitleLabel = UILabel()
    private let cursorSwipeSwitch = UISwitch()

    private var clipboardSeparatorHeightConstraint: NSLayoutConstraint?
    private var systemClipboardActionModeSeparatorHeightConstraint: NSLayoutConstraint?
    private var hapticsSeparatorHeightConstraint: NSLayoutConstraint?
    private var autoCapitalizationSeparatorHeightConstraint: NSLayoutConstraint?
    private var forwardDeleteWithShiftSeparatorHeightConstraint: NSLayoutConstraint?
    private var selectedSystemClipboardActionMode: SystemClipboardActionMode = .pasteAndSave

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        observeTraitChanges()
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(
        isClipboardModeEnabled: Bool,
        isOpenClipboardAfterCopyEnabled: Bool,
        systemClipboardActionMode: SystemClipboardActionMode,
        isAutoCapitalizationEnabled: Bool,
        isCursorSwipeEnabled: Bool,
        isForwardDeleteWithShiftEnabled: Bool,
        isHapticsEnabled: Bool,
        fullAccessStatusText: String?
    ) {
        clipboardSwitch.isOn = isClipboardModeEnabled
        openClipboardAfterCopySwitch.isOn = isOpenClipboardAfterCopyEnabled
        hapticsSwitch.isOn = isHapticsEnabled
        autoCapitalizationSwitch.isOn = isAutoCapitalizationEnabled
        cursorSwipeSwitch.isOn = isCursorSwipeEnabled
        forwardDeleteWithShiftSwitch.isOn = isForwardDeleteWithShiftEnabled
        selectedSystemClipboardActionMode = systemClipboardActionMode
        updateSystemClipboardActionModeButton()

        clipboardSwitch.isEnabled = true
        systemClipboardActionModeButton.isEnabled = true
        clipboardInfoRow.isHidden = fullAccessStatusText?.isEmpty ?? true
        clipboardInfoLabel.text = fullAccessStatusText

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        systemClipboardActionModeTitleLabel.textColor = KeyboardTheme.keyLabelColor
        openClipboardAfterCopyTitleLabel.textColor = KeyboardTheme.keyLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
        forwardDeleteWithShiftTitleLabel.textColor = KeyboardTheme.keyLabelColor
        cursorSwipeTitleLabel.textColor = KeyboardTheme.keyLabelColor
    }

    private func setup() {
        layer.cornerRadius = KeyboardMetrics.settingsPanelCornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = Constants.chromeSpacing
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Constants.contentTopInset,
            leading: Constants.contentHorizontalInset,
            bottom: Constants.contentBottomInset,
            trailing: Constants.contentHorizontalInset
        )

        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.addSubview(scrollContentStack)
        scrollContentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollContentStack.axis = .vertical
        scrollContentStack.alignment = .fill
        scrollContentStack.spacing = Constants.cardSpacing

        configureCloseButton()
        chromeStack.axis = .horizontal
        chromeStack.alignment = .center
        chromeStack.spacing = 8
        chromeStack.addArrangedSubview(UIView())
        chromeStack.addArrangedSubview(closeButton)

        contentStack.addArrangedSubview(chromeStack)
        contentStack.addArrangedSubview(scrollView)

        configureRow(
            clipboardRow,
            titleLabel: clipboardTitleLabel,
            title: "Clipboard Toolbar",
            toggle: clipboardSwitch,
            action: #selector(clipboardSwitchChanged)
        )
        configureSystemClipboardActionModeRow()
        configureRow(
            openClipboardAfterCopyRow,
            titleLabel: openClipboardAfterCopyTitleLabel,
            title: "Open Clipboard After Copy",
            toggle: openClipboardAfterCopySwitch,
            action: #selector(openClipboardAfterCopySwitchChanged)
        )
        configureRow(
            hapticsRow,
            titleLabel: hapticsTitleLabel,
            title: "Key Haptics",
            toggle: hapticsSwitch,
            action: #selector(hapticsSwitchChanged)
        )
        configureRow(
            autoCapitalizationRow,
            titleLabel: autoCapitalizationTitleLabel,
            title: "Auto-capitalization",
            toggle: autoCapitalizationSwitch,
            action: #selector(autoCapitalizationSwitchChanged)
        )
        configureRow(
            forwardDeleteWithShiftRow,
            titleLabel: forwardDeleteWithShiftTitleLabel,
            title: "Forward Delete with Shift",
            toggle: forwardDeleteWithShiftSwitch,
            action: #selector(forwardDeleteWithShiftSwitchChanged)
        )
        configureRow(
            cursorSwipeRow,
            titleLabel: cursorSwipeTitleLabel,
            title: "Swipe Cursor",
            toggle: cursorSwipeSwitch,
            action: #selector(cursorSwipeSwitchChanged)
        )

        configureInfoRows()
        configureCard(clipboardToolsCard, stack: clipboardToolsCardStack)
        configureCard(generalCard, stack: generalCardStack)

        clipboardToolsCardStack.addArrangedSubview(clipboardRow)
        clipboardToolsCardStack.addArrangedSubview(clipboardInfoRow)
        clipboardToolsCardStack.addArrangedSubview(clipboardSeparator)
        clipboardToolsCardStack.addArrangedSubview(systemClipboardActionModeRow)
        clipboardToolsCardStack.addArrangedSubview(systemClipboardActionModeHelperRow)
        clipboardToolsCardStack.addArrangedSubview(systemClipboardActionModeSeparator)
        clipboardToolsCardStack.addArrangedSubview(openClipboardAfterCopyRow)

        generalCardStack.addArrangedSubview(hapticsRow)
        generalCardStack.addArrangedSubview(hapticsSeparator)
        generalCardStack.addArrangedSubview(autoCapitalizationRow)
        generalCardStack.addArrangedSubview(autoCapitalizationSeparator)
        generalCardStack.addArrangedSubview(forwardDeleteWithShiftRow)
        generalCardStack.addArrangedSubview(forwardDeleteWithShiftSeparator)
        generalCardStack.addArrangedSubview(cursorSwipeRow)

        clipboardSeparatorHeightConstraint = clipboardSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        systemClipboardActionModeSeparatorHeightConstraint = systemClipboardActionModeSeparator.heightAnchor.constraint(
            equalToConstant: separatorThickness
        )
        hapticsSeparatorHeightConstraint = hapticsSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        autoCapitalizationSeparatorHeightConstraint = autoCapitalizationSeparator.heightAnchor.constraint(
            equalToConstant: separatorThickness
        )
        forwardDeleteWithShiftSeparatorHeightConstraint = forwardDeleteWithShiftSeparator.heightAnchor.constraint(
            equalToConstant: separatorThickness
        )

        scrollContentStack.addArrangedSubview(clipboardToolsCard)
        scrollContentStack.addArrangedSubview(generalCard)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollContentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
            clipboardSeparatorHeightConstraint!,
            systemClipboardActionModeSeparatorHeightConstraint!,
            hapticsSeparatorHeightConstraint!,
            autoCapitalizationSeparatorHeightConstraint!,
            forwardDeleteWithShiftSeparatorHeightConstraint!
        ])
    }

    private func configureCloseButton() {
        var closeConfiguration = UIButton.Configuration.plain()
        closeConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        closeButton.configuration = closeConfiguration
        closeButton.setSymbolConfigurations(
            normal: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .semibold),
            highlighted: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .bold)
        )
        closeButton.setSymbolImage(UIImage(systemName: "xmark"))
        closeButton.setForegroundColors(
            normal: KeyboardTheme.keyLabelColor,
            highlighted: KeyboardTheme.keyLabelColor
        )
        closeButton.setBackgroundColors(
            normal: .clear,
            highlighted: KeyboardTheme.settingsDonePressedBackground
        )
        closeButton.layer.cornerRadius = 10
        closeButton.layer.cornerCurve = .continuous
        closeButton.accessibilityLabel = "Close settings"
        closeButton.addTarget(self, action: #selector(closeTouchDown), for: .touchDown)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }

    private func configureCard(_ card: UIView, stack: UIStackView) {
        card.layer.cornerRadius = Constants.cardCornerRadius
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
    }

    private func configureInfoRows() {
        clipboardInfoLabel.font = .preferredFont(forTextStyle: .footnote)
        clipboardInfoLabel.numberOfLines = 0
        clipboardInfoLabel.text = "Full Access has never been confirmed on this device."

        clipboardInfoRow.addSubview(clipboardInfoLabel)
        clipboardInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clipboardInfoLabel.topAnchor.constraint(equalTo: clipboardInfoRow.topAnchor),
            clipboardInfoLabel.leadingAnchor.constraint(equalTo: clipboardInfoRow.leadingAnchor, constant: 16),
            clipboardInfoLabel.trailingAnchor.constraint(equalTo: clipboardInfoRow.trailingAnchor, constant: -16),
            clipboardInfoLabel.bottomAnchor.constraint(equalTo: clipboardInfoRow.bottomAnchor, constant: -8)
        ])

        systemClipboardActionModeHelperLabel.font = .preferredFont(forTextStyle: .footnote)
        systemClipboardActionModeHelperLabel.numberOfLines = 0
        systemClipboardActionModeHelperLabel.text = "Choose what SweetKeyboard shows when iOS Clipboard has text copied outside the keyboard."

        systemClipboardActionModeHelperRow.addSubview(systemClipboardActionModeHelperLabel)
        systemClipboardActionModeHelperLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            systemClipboardActionModeHelperLabel.topAnchor.constraint(equalTo: systemClipboardActionModeHelperRow.topAnchor),
            systemClipboardActionModeHelperLabel.leadingAnchor.constraint(
                equalTo: systemClipboardActionModeHelperRow.leadingAnchor,
                constant: 16
            ),
            systemClipboardActionModeHelperLabel.trailingAnchor.constraint(
                equalTo: systemClipboardActionModeHelperRow.trailingAnchor,
                constant: -16
            ),
            systemClipboardActionModeHelperLabel.bottomAnchor.constraint(
                equalTo: systemClipboardActionModeHelperRow.bottomAnchor,
                constant: -8
            )
        ])
    }

    private func configureSystemClipboardActionModeRow() {
        systemClipboardActionModeTitleLabel.font = .preferredFont(forTextStyle: .body)
        systemClipboardActionModeTitleLabel.numberOfLines = 1
        systemClipboardActionModeTitleLabel.text = "iOS Clipboard Action"

        systemClipboardActionModeButton.setTitleFonts(
            normal: .preferredFont(forTextStyle: .subheadline),
            highlighted: .preferredFont(forTextStyle: .subheadline)
        )
        systemClipboardActionModeButton.titleLabel?.adjustsFontSizeToFitWidth = true
        systemClipboardActionModeButton.titleLabel?.minimumScaleFactor = 0.8
        systemClipboardActionModeButton.showsMenuAsPrimaryAction = true
        systemClipboardActionModeButton.accessibilityLabel = "iOS Clipboard Action"
        systemClipboardActionModeButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        systemClipboardActionModeButton.heightAnchor.constraint(equalToConstant: Constants.modeButtonHeight).isActive = true
        systemClipboardActionModeButton.widthAnchor.constraint(
            greaterThanOrEqualToConstant: Constants.modeButtonMinWidth
        ).isActive = true

        systemClipboardActionModeRow.axis = .horizontal
        systemClipboardActionModeRow.alignment = .center
        systemClipboardActionModeRow.spacing = Constants.rowSpacing
        systemClipboardActionModeRow.isLayoutMarginsRelativeArrangement = true
        systemClipboardActionModeRow.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: Constants.rowHorizontalInset,
            bottom: 0,
            trailing: Constants.rowHorizontalInset
        )

        systemClipboardActionModeRow.addArrangedSubview(systemClipboardActionModeTitleLabel)
        systemClipboardActionModeRow.addArrangedSubview(UIView())
        systemClipboardActionModeRow.addArrangedSubview(systemClipboardActionModeButton)
        systemClipboardActionModeRow.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.rowMinHeight).isActive = true
        updateSystemClipboardActionModeButton()
    }

    private func configureRow(
        _ row: UIStackView,
        titleLabel: UILabel,
        title: String,
        toggle: UISwitch,
        action: Selector
    ) {
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.numberOfLines = 1
        titleLabel.text = title

        toggle.addTarget(self, action: action, for: .valueChanged)

        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Constants.rowSpacing
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: Constants.rowHorizontalInset,
            bottom: 0,
            trailing: Constants.rowHorizontalInset
        )

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(toggle)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.rowMinHeight).isActive = true
    }

    private func observeTraitChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) {
            (self: Self, _: UITraitCollection) in
            self.applyTheme()
            self.updateSeparatorThickness()
        }
    }

    private func applyTheme() {
        backgroundColor = KeyboardTheme.settingsScreenBackground
        clipboardToolsCard.backgroundColor = KeyboardTheme.settingsGroupBackground
        generalCard.backgroundColor = KeyboardTheme.settingsGroupBackground
        clipboardSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        systemClipboardActionModeSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        hapticsSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        autoCapitalizationSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        forwardDeleteWithShiftSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        clipboardInfoLabel.textColor = KeyboardTheme.secondaryLabelColor
        systemClipboardActionModeTitleLabel.textColor = KeyboardTheme.keyLabelColor
        systemClipboardActionModeHelperLabel.textColor = KeyboardTheme.secondaryLabelColor
        openClipboardAfterCopyTitleLabel.textColor = KeyboardTheme.keyLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
        forwardDeleteWithShiftTitleLabel.textColor = KeyboardTheme.keyLabelColor
        cursorSwipeTitleLabel.textColor = KeyboardTheme.keyLabelColor

        KeyboardTheme.applyChrome(
            to: systemClipboardActionModeButton,
            role: .utility,
            cornerRadius: Constants.modeButtonHeight / 2
        )
        systemClipboardActionModeButton.setForegroundColors(
            normal: KeyboardTheme.keyLabelColor,
            highlighted: KeyboardTheme.keyLabelColor
        )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateSeparatorThickness()
    }

    @objc private func clipboardSwitchChanged() {
        onClipboardModeChanged?(clipboardSwitch.isOn)
    }

    @objc private func openClipboardAfterCopySwitchChanged() {
        onOpenClipboardAfterCopyChanged?(openClipboardAfterCopySwitch.isOn)
    }

    @objc private func hapticsSwitchChanged() {
        onHapticsEnabledChanged?(hapticsSwitch.isOn)
    }

    @objc private func autoCapitalizationSwitchChanged() {
        onAutoCapitalizationEnabledChanged?(autoCapitalizationSwitch.isOn)
    }

    @objc private func forwardDeleteWithShiftSwitchChanged() {
        onForwardDeleteWithShiftChanged?(forwardDeleteWithShiftSwitch.isOn)
    }

    @objc private func cursorSwipeSwitchChanged() {
        onCursorSwipeEnabledChanged?(cursorSwipeSwitch.isOn)
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func closeTouchDown() {
        onPressDown?()
    }

    @objc private func buttonTouchDown() {
        onPressDown?()
    }

    private func updateSystemClipboardActionModeButton() {
        systemClipboardActionModeButton.setTitle(selectedSystemClipboardActionMode.title, for: .normal)
        systemClipboardActionModeButton.accessibilityValue = selectedSystemClipboardActionMode.title
        systemClipboardActionModeButton.menu = UIMenu(
            children: SystemClipboardActionMode.allCases.map { mode in
                UIAction(
                    title: mode.title,
                    state: mode == selectedSystemClipboardActionMode ? .on : .off
                ) { [weak self] _ in
                    guard let self else {
                        return
                    }

                    self.selectedSystemClipboardActionMode = mode
                    self.updateSystemClipboardActionModeButton()
                    self.onSystemClipboardActionModeChanged?(mode)
                }
            }
        )
    }

    private var separatorThickness: CGFloat {
        1 / max(window?.screen.scale ?? contentScaleFactor, 1)
    }

    private func updateSeparatorThickness() {
        clipboardSeparatorHeightConstraint?.constant = separatorThickness
        systemClipboardActionModeSeparatorHeightConstraint?.constant = separatorThickness
        hapticsSeparatorHeightConstraint?.constant = separatorThickness
        autoCapitalizationSeparatorHeightConstraint?.constant = separatorThickness
        forwardDeleteWithShiftSeparatorHeightConstraint?.constant = separatorThickness
    }
}
