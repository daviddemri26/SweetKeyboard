import UIKit

final class KeyboardSettingsPanelView: UIView {
    var onClipboardModeChanged: ((Bool) -> Void)?
    var onOpenClipboardAfterCopyChanged: ((Bool) -> Void)?
    var onAutoCapitalizationEnabledChanged: ((Bool) -> Void)?
    var onCursorSwipeEnabledChanged: ((Bool) -> Void)?
    var onHapticsEnabledChanged: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    var onPressDown: (() -> Void)?

    private enum Constants {
        static let chromeSpacing: CGFloat = 8
        static let contentTopInset: CGFloat = 6
        static let contentHorizontalInset: CGFloat = 12
        static let contentBottomInset: CGFloat = 8
        static let rowMinHeight: CGFloat = 50
        static let rowHorizontalInset: CGFloat = 16
        static let rowSpacing: CGFloat = 12
        static let cardCornerRadius: CGFloat = 16
    }

    private let contentStack = UIStackView()
    private let chromeStack = UIStackView()
    private let closeButton = KeyboardPressableButton(type: .custom)
    private let scrollView = UIScrollView()
    private let scrollContentStack = UIStackView()

    private let togglesCard = UIView()
    private let togglesCardStack = UIStackView()

    private let clipboardRow = UIStackView()
    private let clipboardTitleLabel = UILabel()
    private let clipboardSwitch = UISwitch()
    private let clipboardInfoRow = UIView()
    private let clipboardInfoLabel = UILabel()
    private let clipboardSeparator = UIView()

    private let openClipboardAfterCopyRow = UIStackView()
    private let openClipboardAfterCopyTitleLabel = UILabel()
    private let openClipboardAfterCopySwitch = UISwitch()
    private let openClipboardAfterCopySeparator = UIView()

    private let hapticsRow = UIStackView()
    private let hapticsTitleLabel = UILabel()
    private let hapticsSwitch = UISwitch()
    private let hapticsSeparator = UIView()

    private let autoCapitalizationRow = UIStackView()
    private let autoCapitalizationTitleLabel = UILabel()
    private let autoCapitalizationSwitch = UISwitch()
    private let autoCapitalizationSeparator = UIView()

    private let cursorSwipeRow = UIStackView()
    private let cursorSwipeTitleLabel = UILabel()
    private let cursorSwipeSwitch = UISwitch()

    private var clipboardSeparatorHeightConstraint: NSLayoutConstraint?
    private var openClipboardAfterCopySeparatorHeightConstraint: NSLayoutConstraint?
    private var hapticsSeparatorHeightConstraint: NSLayoutConstraint?
    private var autoCapitalizationSeparatorHeightConstraint: NSLayoutConstraint?

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
        isAutoCapitalizationEnabled: Bool,
        isCursorSwipeEnabled: Bool,
        isHapticsEnabled: Bool,
        fullAccessStatusText: String?
    ) {
        clipboardSwitch.isOn = isClipboardModeEnabled
        openClipboardAfterCopySwitch.isOn = isOpenClipboardAfterCopyEnabled
        hapticsSwitch.isOn = isHapticsEnabled
        autoCapitalizationSwitch.isOn = isAutoCapitalizationEnabled
        cursorSwipeSwitch.isOn = isCursorSwipeEnabled

        clipboardSwitch.isEnabled = true
        clipboardInfoRow.isHidden = fullAccessStatusText?.isEmpty ?? true
        clipboardInfoLabel.text = fullAccessStatusText

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        openClipboardAfterCopyTitleLabel.textColor = KeyboardTheme.keyLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
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
        scrollContentStack.spacing = 0

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
            title: "Clipboard toolbar",
            toggle: clipboardSwitch,
            action: #selector(clipboardSwitchChanged)
        )
        configureRow(
            openClipboardAfterCopyRow,
            titleLabel: openClipboardAfterCopyTitleLabel,
            title: "Open clipboard after copy",
            toggle: openClipboardAfterCopySwitch,
            action: #selector(openClipboardAfterCopySwitchChanged)
        )
        configureRow(
            hapticsRow,
            titleLabel: hapticsTitleLabel,
            title: "Key haptics",
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
            cursorSwipeRow,
            titleLabel: cursorSwipeTitleLabel,
            title: "Swipe cursor",
            toggle: cursorSwipeSwitch,
            action: #selector(cursorSwipeSwitchChanged)
        )

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

        togglesCard.layer.cornerRadius = Constants.cardCornerRadius
        togglesCard.layer.cornerCurve = .continuous
        togglesCard.clipsToBounds = true

        togglesCardStack.axis = .vertical
        togglesCardStack.alignment = .fill
        togglesCardStack.spacing = 0
        togglesCardStack.addArrangedSubview(clipboardRow)
        togglesCardStack.addArrangedSubview(clipboardInfoRow)
        togglesCardStack.addArrangedSubview(clipboardSeparator)
        togglesCardStack.addArrangedSubview(openClipboardAfterCopyRow)
        togglesCardStack.addArrangedSubview(openClipboardAfterCopySeparator)
        togglesCardStack.addArrangedSubview(hapticsRow)
        togglesCardStack.addArrangedSubview(hapticsSeparator)
        togglesCardStack.addArrangedSubview(autoCapitalizationRow)
        togglesCardStack.addArrangedSubview(autoCapitalizationSeparator)
        togglesCardStack.addArrangedSubview(cursorSwipeRow)

        togglesCard.addSubview(togglesCardStack)
        togglesCardStack.translatesAutoresizingMaskIntoConstraints = false

        clipboardSeparatorHeightConstraint = clipboardSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        openClipboardAfterCopySeparatorHeightConstraint = openClipboardAfterCopySeparator.heightAnchor.constraint(
            equalToConstant: separatorThickness
        )
        hapticsSeparatorHeightConstraint = hapticsSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        autoCapitalizationSeparatorHeightConstraint = autoCapitalizationSeparator.heightAnchor.constraint(
            equalToConstant: separatorThickness
        )

        NSLayoutConstraint.activate([
            togglesCardStack.topAnchor.constraint(equalTo: togglesCard.topAnchor),
            togglesCardStack.leadingAnchor.constraint(equalTo: togglesCard.leadingAnchor),
            togglesCardStack.trailingAnchor.constraint(equalTo: togglesCard.trailingAnchor),
            togglesCardStack.bottomAnchor.constraint(equalTo: togglesCard.bottomAnchor),
            clipboardSeparatorHeightConstraint!,
            openClipboardAfterCopySeparatorHeightConstraint!,
            hapticsSeparatorHeightConstraint!,
            autoCapitalizationSeparatorHeightConstraint!
        ])

        scrollContentStack.addArrangedSubview(togglesCard)

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
            closeButton.heightAnchor.constraint(equalToConstant: 28)
        ])
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
        togglesCard.backgroundColor = KeyboardTheme.settingsGroupBackground
        clipboardSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        openClipboardAfterCopySeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        hapticsSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        autoCapitalizationSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        clipboardInfoLabel.textColor = KeyboardTheme.secondaryLabelColor
        openClipboardAfterCopyTitleLabel.textColor = KeyboardTheme.keyLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
        cursorSwipeTitleLabel.textColor = KeyboardTheme.keyLabelColor
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

    @objc private func cursorSwipeSwitchChanged() {
        onCursorSwipeEnabledChanged?(cursorSwipeSwitch.isOn)
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func closeTouchDown() {
        onPressDown?()
    }

    private var separatorThickness: CGFloat {
        1 / max(window?.screen.scale ?? contentScaleFactor, 1)
    }

    private func updateSeparatorThickness() {
        clipboardSeparatorHeightConstraint?.constant = separatorThickness
        openClipboardAfterCopySeparatorHeightConstraint?.constant = separatorThickness
        hapticsSeparatorHeightConstraint?.constant = separatorThickness
        autoCapitalizationSeparatorHeightConstraint?.constant = separatorThickness
    }
}
