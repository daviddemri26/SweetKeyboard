import UIKit

final class KeyboardSettingsPanelView: UIView {
    var onClipboardModeChanged: ((Bool) -> Void)?
    var onAutoCapitalizationEnabledChanged: ((Bool) -> Void)?
    var onHapticsEnabledChanged: ((Bool) -> Void)?
    var onClose: (() -> Void)?

    private let contentStack = UIStackView()
    private let chromeStack = UIStackView()
    private let closeButton = KeyboardPressableButton(type: .custom)

    private let togglesCard = UIView()
    private let togglesCardStack = UIStackView()

    private let clipboardRow = UIStackView()
    private let clipboardTitleLabel = UILabel()
    private let clipboardSwitch = UISwitch()
    private let clipboardInfoRow = UIView()
    private let clipboardInfoLabel = UILabel()
    private let clipboardSeparator = UIView()

    private let hapticsRow = UIStackView()
    private let hapticsTitleLabel = UILabel()
    private let hapticsSwitch = UISwitch()
    private let hapticsSeparator = UIView()

    private let autoCapitalizationRow = UIStackView()
    private let autoCapitalizationTitleLabel = UILabel()
    private let autoCapitalizationSwitch = UISwitch()

    private var clipboardSeparatorHeightConstraint: NSLayoutConstraint?
    private var hapticsSeparatorHeightConstraint: NSLayoutConstraint?

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
        isAutoCapitalizationEnabled: Bool,
        isHapticsEnabled: Bool,
        fullAccessStatusText: String?
    ) {
        clipboardSwitch.isOn = isClipboardModeEnabled
        hapticsSwitch.isOn = isHapticsEnabled
        autoCapitalizationSwitch.isOn = isAutoCapitalizationEnabled

        clipboardSwitch.isEnabled = true
        clipboardInfoRow.isHidden = fullAccessStatusText?.isEmpty ?? true
        clipboardInfoLabel.text = fullAccessStatusText

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
    }

    private func setup() {
        layer.cornerRadius = KeyboardMetrics.settingsPanelCornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 8
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 8, trailing: 12)

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
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        chromeStack.axis = .horizontal
        chromeStack.alignment = .center
        chromeStack.spacing = 8
        chromeStack.addArrangedSubview(UIView())
        chromeStack.addArrangedSubview(closeButton)

        contentStack.addArrangedSubview(chromeStack)

        configureRow(
            clipboardRow,
            titleLabel: clipboardTitleLabel,
            title: "Clipboard toolbar",
            toggle: clipboardSwitch,
            action: #selector(clipboardSwitchChanged)
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

        togglesCard.layer.cornerRadius = 16
        togglesCard.layer.cornerCurve = .continuous
        togglesCard.clipsToBounds = true

        togglesCardStack.axis = .vertical
        togglesCardStack.alignment = .fill
        togglesCardStack.spacing = 0
        togglesCardStack.addArrangedSubview(clipboardRow)
        togglesCardStack.addArrangedSubview(clipboardInfoRow)
        togglesCardStack.addArrangedSubview(clipboardSeparator)
        togglesCardStack.addArrangedSubview(hapticsRow)
        togglesCardStack.addArrangedSubview(hapticsSeparator)
        togglesCardStack.addArrangedSubview(autoCapitalizationRow)

        togglesCard.addSubview(togglesCardStack)
        togglesCardStack.translatesAutoresizingMaskIntoConstraints = false

        clipboardSeparatorHeightConstraint = clipboardSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        hapticsSeparatorHeightConstraint = hapticsSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)

        NSLayoutConstraint.activate([
            togglesCardStack.topAnchor.constraint(equalTo: togglesCard.topAnchor),
            togglesCardStack.leadingAnchor.constraint(equalTo: togglesCard.leadingAnchor),
            togglesCardStack.trailingAnchor.constraint(equalTo: togglesCard.trailingAnchor),
            togglesCardStack.bottomAnchor.constraint(equalTo: togglesCard.bottomAnchor),
            clipboardSeparatorHeightConstraint!,
            hapticsSeparatorHeightConstraint!
        ])

        contentStack.addArrangedSubview(togglesCard)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
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
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(toggle)
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
        hapticsSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor

        clipboardTitleLabel.textColor = KeyboardTheme.keyLabelColor
        clipboardInfoLabel.textColor = KeyboardTheme.secondaryLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor
        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateSeparatorThickness()
    }

    @objc private func clipboardSwitchChanged() {
        onClipboardModeChanged?(clipboardSwitch.isOn)
    }

    @objc private func hapticsSwitchChanged() {
        onHapticsEnabledChanged?(hapticsSwitch.isOn)
    }

    @objc private func autoCapitalizationSwitchChanged() {
        onAutoCapitalizationEnabledChanged?(autoCapitalizationSwitch.isOn)
    }

    @objc private func closeTapped() {
        onClose?()
    }

    private var separatorThickness: CGFloat {
        1 / max(window?.screen.scale ?? contentScaleFactor, 1)
    }

    private func updateSeparatorThickness() {
        clipboardSeparatorHeightConstraint?.constant = separatorThickness
        hapticsSeparatorHeightConstraint?.constant = separatorThickness
    }
}
