import UIKit

final class KeyboardSettingsPanelView: UIView {
    var onClipboardModeChanged: ((Bool) -> Void)?
    var onOpenClipboardAfterCopyChanged: ((Bool) -> Void)?
    var onSystemClipboardActionsChanged: ((Set<SystemClipboardAction>) -> Void)?
    var onAutoCapitalizationEnabledChanged: ((Bool) -> Void)?
    var onCursorSwipeEnabledChanged: ((Bool) -> Void)?
    var onForwardDeleteWithShiftChanged: ((Bool) -> Void)?
    var onHapticsEnabledChanged: ((Bool) -> Void)?
    var onViewMoreInfo: (() -> Void)?
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
        static let actionButtonSize: CGFloat = 42
        static let actionOptionVerticalInset: CGFloat = 4
    }

    private let contentStack = UIStackView()
    private let chromeStack = UIStackView()
    private let viewMoreInfoContainer = UIView()
    private let viewMoreInfoButton = UIButton(type: .system)
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

    private let systemClipboardActionsSection = UIStackView()
    private let systemClipboardActionsTitleLabel = UILabel()

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
    private var hapticsSeparatorHeightConstraint: NSLayoutConstraint?
    private var autoCapitalizationSeparatorHeightConstraint: NSLayoutConstraint?
    private var forwardDeleteWithShiftSeparatorHeightConstraint: NSLayoutConstraint?
    private var selectedSystemClipboardActions: Set<SystemClipboardAction> = [.pasteAndSave]
    private var systemClipboardActionButtons: [SystemClipboardAction: KeyboardPressableButton] = [:]
    private var systemClipboardActionTitleLabels: [SystemClipboardAction: UILabel] = [:]
    private weak var customViewMoreInfoView: UIView?

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
        systemClipboardActions: Set<SystemClipboardAction>,
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
        selectedSystemClipboardActions = systemClipboardActions
        updateSystemClipboardActionButtons()

        clipboardSwitch.isEnabled = true
        clipboardInfoRow.isHidden = fullAccessStatusText?.isEmpty ?? true
        clipboardInfoLabel.text = fullAccessStatusText

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        systemClipboardActionsTitleLabel.textColor = KeyboardTheme.keyLabelColor
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

        configureViewMoreInfoButton()
        configureCloseButton()
        chromeStack.axis = .horizontal
        chromeStack.alignment = .center
        chromeStack.spacing = 8
        chromeStack.addArrangedSubview(viewMoreInfoContainer)
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
        configureSystemClipboardActionsSection()
        configureRow(
            openClipboardAfterCopyRow,
            titleLabel: openClipboardAfterCopyTitleLabel,
            title: "Open Clipboard After Copy",
            toggle: openClipboardAfterCopySwitch,
            action: #selector(openClipboardAfterCopySwitchChanged)
        )
        configureRow(
            autoCapitalizationRow,
            titleLabel: autoCapitalizationTitleLabel,
            title: "Auto-capitalization",
            toggle: autoCapitalizationSwitch,
            action: #selector(autoCapitalizationSwitchChanged)
        )
        configureRow(
            hapticsRow,
            titleLabel: hapticsTitleLabel,
            title: "Key Haptics",
            toggle: hapticsSwitch,
            action: #selector(hapticsSwitchChanged)
        )
        configureRow(
            cursorSwipeRow,
            titleLabel: cursorSwipeTitleLabel,
            title: "Swipe Cursor",
            toggle: cursorSwipeSwitch,
            action: #selector(cursorSwipeSwitchChanged)
        )
        configureRow(
            forwardDeleteWithShiftRow,
            titleLabel: forwardDeleteWithShiftTitleLabel,
            title: "Forward Delete with Shift",
            toggle: forwardDeleteWithShiftSwitch,
            action: #selector(forwardDeleteWithShiftSwitchChanged)
        )

        configureInfoRow()
        configureCard(clipboardToolsCard, stack: clipboardToolsCardStack)
        configureCard(generalCard, stack: generalCardStack)

        clipboardToolsCardStack.addArrangedSubview(clipboardRow)
        clipboardToolsCardStack.addArrangedSubview(openClipboardAfterCopyRow)
        clipboardToolsCardStack.addArrangedSubview(clipboardInfoRow)
        clipboardToolsCardStack.addArrangedSubview(clipboardSeparator)
        clipboardToolsCardStack.addArrangedSubview(systemClipboardActionsSection)

        generalCardStack.addArrangedSubview(autoCapitalizationRow)
        generalCardStack.addArrangedSubview(autoCapitalizationSeparator)
        generalCardStack.addArrangedSubview(hapticsRow)
        generalCardStack.addArrangedSubview(hapticsSeparator)
        generalCardStack.addArrangedSubview(cursorSwipeRow)
        generalCardStack.addArrangedSubview(forwardDeleteWithShiftSeparator)
        generalCardStack.addArrangedSubview(forwardDeleteWithShiftRow)

        clipboardSeparatorHeightConstraint = clipboardSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
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
            viewMoreInfoButton.topAnchor.constraint(equalTo: viewMoreInfoContainer.topAnchor),
            viewMoreInfoButton.leadingAnchor.constraint(equalTo: viewMoreInfoContainer.leadingAnchor),
            viewMoreInfoButton.trailingAnchor.constraint(equalTo: viewMoreInfoContainer.trailingAnchor),
            viewMoreInfoButton.bottomAnchor.constraint(equalTo: viewMoreInfoContainer.bottomAnchor),
            clipboardSeparatorHeightConstraint!,
            hapticsSeparatorHeightConstraint!,
            autoCapitalizationSeparatorHeightConstraint!,
            forwardDeleteWithShiftSeparatorHeightConstraint!
        ])
    }

    func setViewMoreInfoView(_ view: UIView) {
        customViewMoreInfoView?.removeFromSuperview()
        viewMoreInfoButton.removeFromSuperview()

        customViewMoreInfoView = view
        viewMoreInfoContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: viewMoreInfoContainer.topAnchor),
            view.leadingAnchor.constraint(equalTo: viewMoreInfoContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: viewMoreInfoContainer.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: viewMoreInfoContainer.bottomAnchor)
        ])
    }

    private func configureViewMoreInfoButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "View More Info"
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 8)
        configuration.baseForegroundColor = KeyboardTheme.keyLabelColor
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .preferredFont(forTextStyle: .footnote)
            return outgoing
        }
        viewMoreInfoButton.configuration = configuration
        viewMoreInfoButton.configurationUpdateHandler = { button in
            var updatedConfiguration = button.configuration ?? .plain()
            updatedConfiguration.baseForegroundColor = button.isHighlighted
                ? KeyboardTheme.keyLabelColor.withAlphaComponent(0.72)
                : KeyboardTheme.keyLabelColor
            updatedConfiguration.background.backgroundColor = button.isHighlighted
                ? KeyboardTheme.settingsDonePressedBackground
                : .clear
            button.configuration = updatedConfiguration
        }
        viewMoreInfoButton.layer.cornerRadius = 8
        viewMoreInfoButton.layer.cornerCurve = .continuous
        viewMoreInfoButton.accessibilityLabel = "View More Info"
        viewMoreInfoButton.accessibilityHint = "Opens SweetKeyboard settings in the app."
        viewMoreInfoButton.addTarget(self, action: #selector(viewMoreInfoTouchDown), for: .touchDown)
        viewMoreInfoButton.addTarget(self, action: #selector(viewMoreInfoTapped), for: .touchUpInside)
        viewMoreInfoButton.translatesAutoresizingMaskIntoConstraints = false
        viewMoreInfoContainer.addSubview(viewMoreInfoButton)
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

    private func configureInfoRow() {
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
    }

    private func configureSystemClipboardActionsSection() {
        systemClipboardActionsSection.axis = .vertical
        systemClipboardActionsSection.alignment = .fill
        systemClipboardActionsSection.spacing = 4
        systemClipboardActionsSection.isLayoutMarginsRelativeArrangement = true
        systemClipboardActionsSection.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 12,
            leading: Constants.rowHorizontalInset,
            bottom: 12,
            trailing: Constants.rowHorizontalInset
        )

        systemClipboardActionsTitleLabel.font = .preferredFont(forTextStyle: .body)
        systemClipboardActionsTitleLabel.numberOfLines = 1
        systemClipboardActionsTitleLabel.text = "Native iPhone Clipboard Buttons"

        systemClipboardActionsSection.addArrangedSubview(systemClipboardActionsTitleLabel)

        SystemClipboardAction.allCases.forEach { action in
            systemClipboardActionsSection.addArrangedSubview(makeSystemClipboardActionOption(for: action))
        }
    }

    private func makeSystemClipboardActionOption(for action: SystemClipboardAction) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Constants.actionOptionVerticalInset,
            leading: 0,
            bottom: Constants.actionOptionVerticalInset,
            trailing: 0
        )

        let button = KeyboardPressableButton(type: .custom)
        button.setSymbolConfigurations(
            normal: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .medium),
            highlighted: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .semibold)
        )
        button.setSymbolImage(action.symbolNames.lazy.compactMap { UIImage(systemName: $0) }.first)
        button.layer.cornerRadius = KeyboardMetrics.nativeClipboardButtonCornerRadius
        button.layer.cornerCurve = .continuous
        button.accessibilityLabel = action.title
        button.accessibilityHint = action.detail
        button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        button.addAction(UIAction { [weak self] _ in
            self?.toggleSystemClipboardAction(action)
        }, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: Constants.actionButtonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: Constants.actionButtonSize).isActive = true

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.numberOfLines = 1
        titleLabel.text = action.title

        row.addArrangedSubview(button)
        row.addArrangedSubview(titleLabel)

        systemClipboardActionButtons[action] = button
        systemClipboardActionTitleLabels[action] = titleLabel
        return row
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
        hapticsSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        autoCapitalizationSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        forwardDeleteWithShiftSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        clipboardInfoLabel.textColor = KeyboardTheme.secondaryLabelColor
        viewMoreInfoButton.setNeedsUpdateConfiguration()
        systemClipboardActionsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        openClipboardAfterCopyTitleLabel.textColor = KeyboardTheme.keyLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
        forwardDeleteWithShiftTitleLabel.textColor = KeyboardTheme.keyLabelColor
        cursorSwipeTitleLabel.textColor = KeyboardTheme.keyLabelColor

        updateSystemClipboardActionButtons()
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

    @objc private func viewMoreInfoTapped() {
        onViewMoreInfo?()
    }

    @objc private func viewMoreInfoTouchDown() {
        onPressDown?()
    }

    @objc private func closeTouchDown() {
        onPressDown?()
    }

    @objc private func buttonTouchDown() {
        onPressDown?()
    }

    private func toggleSystemClipboardAction(_ action: SystemClipboardAction) {
        if selectedSystemClipboardActions.contains(action) {
            selectedSystemClipboardActions.remove(action)
        } else {
            selectedSystemClipboardActions.insert(action)
        }

        updateSystemClipboardActionButtons()
        onSystemClipboardActionsChanged?(selectedSystemClipboardActions)
    }

    private func updateSystemClipboardActionButtons() {
        SystemClipboardAction.allCases.forEach { action in
            guard let button = systemClipboardActionButtons[action] else {
                return
            }

            let isSelected = selectedSystemClipboardActions.contains(action)
            button.isSelected = isSelected
            button.accessibilityTraits = isSelected ? [.button, .selected] : [.button]

            if isSelected {
                button.setBackgroundColors(
                    normal: KeyboardTheme.settingsAccentColor,
                    highlighted: KeyboardTheme.settingsAccentColor.withAlphaComponent(0.82)
                )
                button.setForegroundColors(normal: .white, highlighted: .white)
                button.setBorder(width: 0)
                button.layer.cornerRadius = KeyboardMetrics.nativeClipboardButtonCornerRadius
                button.layer.cornerCurve = .continuous
            } else {
                KeyboardTheme.applyChrome(
                    to: button,
                    role: .utility,
                    cornerRadius: KeyboardMetrics.nativeClipboardButtonCornerRadius
                )
                button.setForegroundColors(
                    normal: KeyboardTheme.keyLabelColor,
                    highlighted: KeyboardTheme.keyLabelColor
                )
            }

            systemClipboardActionTitleLabels[action]?.textColor = KeyboardTheme.keyLabelColor
        }
    }

    private var separatorThickness: CGFloat {
        1 / max(window?.screen.scale ?? contentScaleFactor, 1)
    }

    private func updateSeparatorThickness() {
        clipboardSeparatorHeightConstraint?.constant = separatorThickness
        hapticsSeparatorHeightConstraint?.constant = separatorThickness
        autoCapitalizationSeparatorHeightConstraint?.constant = separatorThickness
        forwardDeleteWithShiftSeparatorHeightConstraint?.constant = separatorThickness
    }
}
