import UIKit

final class KeyboardSettingsPanelView: UIView {
    var onClipboardModeChanged: ((Bool) -> Void)?
    var onAutoCapitalizationEnabledChanged: ((Bool) -> Void)?
    var onHapticsEnabledChanged: ((Bool) -> Void)?
    var onDone: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let headerStack = UIStackView()
    private let titleLabel = UILabel()
    private let doneButton = KeyboardPressableButton(type: .custom)

    private let featuresSectionLabel = UILabel()
    private let featuresCard = UIView()
    private let featuresCardStack = UIStackView()
    private let autoCapitalizationToggleRow = UIStackView()
    private let autoCapitalizationTitleLabel = UILabel()
    private let autoCapitalizationSwitch = UISwitch()
    private let autoCapitalizationSeparator = UIView()
    private let autoCapitalizationHelperRow = UIView()
    private let autoCapitalizationHelperLabel = UILabel()
    private let toggleRow = UIStackView()
    private let toggleTitleLabel = UILabel()
    private let clipboardSwitch = UISwitch()
    private let toggleSeparator = UIView()
    private let helperRow = UIView()
    private let helperLabel = UILabel()
    private var autoCapitalizationSeparatorHeightConstraint: NSLayoutConstraint?
    private var toggleSeparatorHeightConstraint: NSLayoutConstraint?

    private let feedbackSectionLabel = UILabel()
    private let feedbackCard = UIView()
    private let feedbackCardStack = UIStackView()
    private let hapticsToggleRow = UIStackView()
    private let hapticsTitleLabel = UILabel()
    private let hapticsSwitch = UISwitch()
    private let hapticsHelperRow = UIView()
    private let hapticsHelperLabel = UILabel()

    private let privacySectionLabel = UILabel()
    private let privacyCard = UIView()
    private let privacyLabel = UILabel()

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
        showsClipboardToggle: Bool,
        isClipboardToggleEnabled: Bool,
        helperText: String?
    ) {
        autoCapitalizationSwitch.isOn = isAutoCapitalizationEnabled
        clipboardSwitch.isOn = isClipboardModeEnabled
        hapticsSwitch.isOn = isHapticsEnabled
        toggleRow.isHidden = !showsClipboardToggle
        toggleSeparator.isHidden = !showsClipboardToggle
        clipboardSwitch.isEnabled = isClipboardToggleEnabled

        autoCapitalizationTitleLabel.textColor = KeyboardTheme.keyLabelColor
        toggleTitleLabel.textColor = isClipboardToggleEnabled
            ? KeyboardTheme.keyLabelColor
            : KeyboardTheme.secondaryLabelColor
        hapticsTitleLabel.textColor = KeyboardTheme.keyLabelColor

        helperLabel.text = helperText
        helperRow.isHidden = helperText?.isEmpty ?? true
    }

    private func setup() {
        layer.cornerRadius = KeyboardMetrics.settingsPanelCornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 18
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.text = "Settings"

        var doneConfiguration = UIButton.Configuration.plain()
        doneConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        doneButton.configuration = doneConfiguration
        let doneButtonFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleFonts(
            normal: doneButtonFont,
            highlighted: doneButtonFont
        )
        doneButton.setForegroundColors(
            normal: KeyboardTheme.settingsAccentColor,
            highlighted: KeyboardTheme.settingsAccentColor
        )
        doneButton.setBackgroundColors(
            normal: .clear,
            highlighted: KeyboardTheme.settingsDonePressedBackground
        )
        doneButton.layer.cornerRadius = 10
        doneButton.layer.cornerCurve = .continuous
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(doneButton)

        featuresSectionLabel.font = .preferredFont(forTextStyle: .caption1)
        featuresSectionLabel.text = "KEYBOARD FEATURES"

        autoCapitalizationTitleLabel.font = .preferredFont(forTextStyle: .body)
        autoCapitalizationTitleLabel.numberOfLines = 0
        autoCapitalizationTitleLabel.text = "Auto-capitalization"

        autoCapitalizationSwitch.addTarget(self, action: #selector(autoCapitalizationSwitchChanged), for: .valueChanged)

        autoCapitalizationToggleRow.axis = .horizontal
        autoCapitalizationToggleRow.alignment = .center
        autoCapitalizationToggleRow.spacing = 12
        autoCapitalizationToggleRow.isLayoutMarginsRelativeArrangement = true
        autoCapitalizationToggleRow.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        autoCapitalizationToggleRow.addArrangedSubview(autoCapitalizationTitleLabel)
        autoCapitalizationToggleRow.addArrangedSubview(UIView())
        autoCapitalizationToggleRow.addArrangedSubview(autoCapitalizationSwitch)

        autoCapitalizationHelperLabel.font = .preferredFont(forTextStyle: .footnote)
        autoCapitalizationHelperLabel.numberOfLines = 0
        autoCapitalizationHelperLabel.text = "Starts with Shift active when the field suggests a capital letter, like at the beginning of a sentence."

        autoCapitalizationHelperRow.addSubview(autoCapitalizationHelperLabel)
        autoCapitalizationHelperLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            autoCapitalizationHelperLabel.topAnchor.constraint(equalTo: autoCapitalizationHelperRow.topAnchor, constant: 12),
            autoCapitalizationHelperLabel.leadingAnchor.constraint(equalTo: autoCapitalizationHelperRow.leadingAnchor, constant: 16),
            autoCapitalizationHelperLabel.trailingAnchor.constraint(equalTo: autoCapitalizationHelperRow.trailingAnchor, constant: -16),
            autoCapitalizationHelperLabel.bottomAnchor.constraint(equalTo: autoCapitalizationHelperRow.bottomAnchor, constant: -12)
        ])

        toggleTitleLabel.font = .preferredFont(forTextStyle: .body)
        toggleTitleLabel.numberOfLines = 0
        toggleTitleLabel.text = "Clipboard toolbar"

        clipboardSwitch.addTarget(self, action: #selector(clipboardSwitchChanged), for: .valueChanged)

        toggleRow.axis = .horizontal
        toggleRow.alignment = .center
        toggleRow.spacing = 12
        toggleRow.isLayoutMarginsRelativeArrangement = true
        toggleRow.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        toggleRow.addArrangedSubview(toggleTitleLabel)
        toggleRow.addArrangedSubview(UIView())
        toggleRow.addArrangedSubview(clipboardSwitch)

        helperLabel.font = .preferredFont(forTextStyle: .footnote)
        helperLabel.numberOfLines = 0

        helperRow.addSubview(helperLabel)
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            helperLabel.topAnchor.constraint(equalTo: helperRow.topAnchor, constant: 12),
            helperLabel.leadingAnchor.constraint(equalTo: helperRow.leadingAnchor, constant: 16),
            helperLabel.trailingAnchor.constraint(equalTo: helperRow.trailingAnchor, constant: -16),
            helperLabel.bottomAnchor.constraint(equalTo: helperRow.bottomAnchor, constant: -12)
        ])

        featuresCard.layer.cornerRadius = 14
        featuresCard.layer.cornerCurve = .continuous
        featuresCard.clipsToBounds = true

        featuresCardStack.axis = .vertical
        featuresCardStack.alignment = .fill
        featuresCardStack.spacing = 0
        featuresCardStack.addArrangedSubview(autoCapitalizationToggleRow)
        featuresCardStack.addArrangedSubview(autoCapitalizationSeparator)
        featuresCardStack.addArrangedSubview(autoCapitalizationHelperRow)
        featuresCardStack.addArrangedSubview(toggleRow)
        featuresCardStack.addArrangedSubview(toggleSeparator)
        featuresCardStack.addArrangedSubview(helperRow)

        featuresCard.addSubview(featuresCardStack)
        featuresCardStack.translatesAutoresizingMaskIntoConstraints = false
        autoCapitalizationSeparatorHeightConstraint = autoCapitalizationSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        toggleSeparatorHeightConstraint = toggleSeparator.heightAnchor.constraint(equalToConstant: separatorThickness)
        NSLayoutConstraint.activate([
            featuresCardStack.topAnchor.constraint(equalTo: featuresCard.topAnchor),
            featuresCardStack.leadingAnchor.constraint(equalTo: featuresCard.leadingAnchor),
            featuresCardStack.trailingAnchor.constraint(equalTo: featuresCard.trailingAnchor),
            featuresCardStack.bottomAnchor.constraint(equalTo: featuresCard.bottomAnchor),
            autoCapitalizationSeparatorHeightConstraint!,
            toggleSeparatorHeightConstraint!
        ])

        feedbackSectionLabel.font = .preferredFont(forTextStyle: .caption1)
        feedbackSectionLabel.text = "FEEDBACK"

        hapticsTitleLabel.font = .preferredFont(forTextStyle: .body)
        hapticsTitleLabel.numberOfLines = 0
        hapticsTitleLabel.text = "Key haptics"

        hapticsSwitch.addTarget(self, action: #selector(hapticsSwitchChanged), for: .valueChanged)

        hapticsToggleRow.axis = .horizontal
        hapticsToggleRow.alignment = .center
        hapticsToggleRow.spacing = 12
        hapticsToggleRow.isLayoutMarginsRelativeArrangement = true
        hapticsToggleRow.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        hapticsToggleRow.addArrangedSubview(hapticsTitleLabel)
        hapticsToggleRow.addArrangedSubview(UIView())
        hapticsToggleRow.addArrangedSubview(hapticsSwitch)

        hapticsHelperLabel.font = .preferredFont(forTextStyle: .footnote)
        hapticsHelperLabel.numberOfLines = 0
        hapticsHelperLabel.text = "Adds a light tap on letters, function keys, and clipboard actions when supported by the device."

        hapticsHelperRow.addSubview(hapticsHelperLabel)
        hapticsHelperLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hapticsHelperLabel.topAnchor.constraint(equalTo: hapticsHelperRow.topAnchor, constant: 12),
            hapticsHelperLabel.leadingAnchor.constraint(equalTo: hapticsHelperRow.leadingAnchor, constant: 16),
            hapticsHelperLabel.trailingAnchor.constraint(equalTo: hapticsHelperRow.trailingAnchor, constant: -16),
            hapticsHelperLabel.bottomAnchor.constraint(equalTo: hapticsHelperRow.bottomAnchor, constant: -12)
        ])

        feedbackCard.layer.cornerRadius = 14
        feedbackCard.layer.cornerCurve = .continuous
        feedbackCard.clipsToBounds = true

        feedbackCardStack.axis = .vertical
        feedbackCardStack.alignment = .fill
        feedbackCardStack.spacing = 0
        feedbackCardStack.addArrangedSubview(hapticsToggleRow)
        feedbackCardStack.addArrangedSubview(hapticsHelperRow)

        feedbackCard.addSubview(feedbackCardStack)
        feedbackCardStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            feedbackCardStack.topAnchor.constraint(equalTo: feedbackCard.topAnchor),
            feedbackCardStack.leadingAnchor.constraint(equalTo: feedbackCard.leadingAnchor),
            feedbackCardStack.trailingAnchor.constraint(equalTo: feedbackCard.trailingAnchor),
            feedbackCardStack.bottomAnchor.constraint(equalTo: feedbackCard.bottomAnchor)
        ])

        privacySectionLabel.font = .preferredFont(forTextStyle: .caption1)
        privacySectionLabel.text = "PRIVACY"

        privacyLabel.font = .preferredFont(forTextStyle: .footnote)
        privacyLabel.numberOfLines = 0
        privacyLabel.text = "Clipboard data stays on this device. No network, no analytics, no cloud sync."

        privacyCard.layer.cornerRadius = 14
        privacyCard.layer.cornerCurve = .continuous
        privacyCard.clipsToBounds = true
        privacyCard.addSubview(privacyLabel)
        privacyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            privacyLabel.topAnchor.constraint(equalTo: privacyCard.topAnchor, constant: 12),
            privacyLabel.leadingAnchor.constraint(equalTo: privacyCard.leadingAnchor, constant: 16),
            privacyLabel.trailingAnchor.constraint(equalTo: privacyCard.trailingAnchor, constant: -16),
            privacyLabel.bottomAnchor.constraint(equalTo: privacyCard.bottomAnchor, constant: -12)
        ])

        contentStack.addArrangedSubview(featuresSectionLabel)
        contentStack.addArrangedSubview(featuresCard)
        contentStack.addArrangedSubview(feedbackSectionLabel)
        contentStack.addArrangedSubview(feedbackCard)
        contentStack.addArrangedSubview(privacySectionLabel)
        contentStack.addArrangedSubview(privacyCard)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            doneButton.heightAnchor.constraint(equalToConstant: 32),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
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
        scrollView.backgroundColor = .clear

        titleLabel.textColor = KeyboardTheme.keyLabelColor

        featuresSectionLabel.textColor = KeyboardTheme.secondaryLabelColor
        feedbackSectionLabel.textColor = KeyboardTheme.secondaryLabelColor
        privacySectionLabel.textColor = KeyboardTheme.secondaryLabelColor

        featuresCard.backgroundColor = KeyboardTheme.settingsGroupBackground
        feedbackCard.backgroundColor = KeyboardTheme.settingsGroupBackground
        privacyCard.backgroundColor = KeyboardTheme.settingsGroupBackground
        autoCapitalizationSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor
        toggleSeparator.backgroundColor = KeyboardTheme.settingsSeparatorColor

        autoCapitalizationHelperLabel.textColor = KeyboardTheme.secondaryLabelColor
        helperLabel.textColor = KeyboardTheme.secondaryLabelColor
        hapticsHelperLabel.textColor = KeyboardTheme.secondaryLabelColor
        privacyLabel.textColor = KeyboardTheme.secondaryLabelColor
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateSeparatorThickness()
    }

    @objc private func clipboardSwitchChanged() {
        onClipboardModeChanged?(clipboardSwitch.isOn)
    }

    @objc private func autoCapitalizationSwitchChanged() {
        onAutoCapitalizationEnabledChanged?(autoCapitalizationSwitch.isOn)
    }

    @objc private func hapticsSwitchChanged() {
        onHapticsEnabledChanged?(hapticsSwitch.isOn)
    }

    @objc private func doneTapped() {
        onDone?()
    }

    private var separatorThickness: CGFloat {
        1 / max(window?.screen.scale ?? contentScaleFactor, 1)
    }

    private func updateSeparatorThickness() {
        autoCapitalizationSeparatorHeightConstraint?.constant = separatorThickness
        toggleSeparatorHeightConstraint?.constant = separatorThickness
    }
}
