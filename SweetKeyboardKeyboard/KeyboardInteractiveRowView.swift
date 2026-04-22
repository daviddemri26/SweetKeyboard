import UIKit

final class KeyboardHitTargetButton: UIButton {
    weak var visualButton: UIButton? {
        didSet {
            syncFromVisualButton()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            visualButton?.isHighlighted = isHighlighted
        }
    }

    override var isEnabled: Bool {
        didSet {
            visualButton?.isEnabled = isEnabled
        }
    }

    func syncFromVisualButton() {
        guard let visualButton else {
            return
        }

        setTitle(visualButton.title(for: .normal), for: .normal)
        setTitle(visualButton.title(for: .highlighted), for: .highlighted)
        setImage(visualButton.image(for: .normal), for: .normal)
        setImage(visualButton.image(for: .highlighted), for: .highlighted)
        accessibilityLabel = visualButton.accessibilityLabel
        accessibilityHint = visualButton.accessibilityHint
        accessibilityIdentifier = visualButton.accessibilityIdentifier
        accessibilityTraits = visualButton.accessibilityTraits
        tag = visualButton.tag
        isEnabled = visualButton.isEnabled
        visualButton.isHighlighted = isHighlighted
    }

    func applyTransparentAppearance() {
        backgroundColor = .clear
        tintColor = .clear
        setTitleColor(.clear, for: .normal)
        setTitleColor(.clear, for: .highlighted)
        setTitleColor(.clear, for: .selected)
        setTitleColor(.clear, for: .disabled)
        layer.cornerRadius = 0
        layer.cornerCurve = .continuous
        layer.borderWidth = 0
        layer.borderColor = UIColor.clear.cgColor
    }
}

final class KeyboardInteractiveRowView: UIView {
    let visualRow = UIStackView()

    private var hitTargets: [KeyboardHitTargetButton] = []
    private var visualButtons: [UIButton] = []
    private var visualRowTopConstraint: NSLayoutConstraint?
    private var visualRowBottomConstraint: NSLayoutConstraint?
    private var rowHeightConstraint: NSLayoutConstraint?
    private let keyHeight: CGFloat

    init(topInset: CGFloat, bottomInset: CGFloat, keyHeight: CGFloat, visualRowSpacing: CGFloat) {
        self.keyHeight = keyHeight
        super.init(frame: .zero)

        isAccessibilityElement = false

        visualRow.axis = .horizontal
        visualRow.distribution = .fill
        visualRow.alignment = .fill
        visualRow.spacing = visualRowSpacing
        visualRow.setContentHuggingPriority(.required, for: .vertical)
        visualRow.setContentCompressionResistancePriority(.required, for: .vertical)
        visualRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualRow)

        let topConstraint = visualRow.topAnchor.constraint(equalTo: topAnchor, constant: topInset)
        let bottomConstraint = visualRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset)
        visualRowTopConstraint = topConstraint
        visualRowBottomConstraint = bottomConstraint
        rowHeightConstraint = heightAnchor.constraint(
            equalToConstant: KeyboardTouchLayoutCalculator.rowHeight(
                keyHeight: keyHeight,
                insets: KeyboardTouchRowInsets(top: topInset, bottom: bottomInset)
            )
        )

        NSLayoutConstraint.activate([
            visualRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            topConstraint,
            bottomConstraint,
            rowHeightConstraint!
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addKey(visualButton: UIButton, hitTarget: KeyboardHitTargetButton) {
        visualButtons.append(visualButton)
        hitTargets.append(hitTarget)
        visualRow.addArrangedSubview(visualButton)

        hitTarget.translatesAutoresizingMaskIntoConstraints = true
        hitTarget.visualButton = visualButton
        hitTarget.applyTransparentAppearance()
        addSubview(hitTarget)
    }

    func setBottomInset(_ bottomInset: CGFloat) {
        guard let topInset = visualRowTopConstraint?.constant else {
            return
        }

        visualRowBottomConstraint?.constant = -bottomInset
        rowHeightConstraint?.constant = KeyboardTouchLayoutCalculator.rowHeight(
            keyHeight: keyHeight,
            insets: KeyboardTouchRowInsets(top: topInset, bottom: bottomInset)
        )
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        visualRow.layoutIfNeeded()

        let touchFrames = KeyboardTouchLayoutCalculator.touchFrames(
            for: visualButtons.map { button in
                convert(button.frame, from: visualRow)
            },
            in: bounds
        )

        for (hitTarget, frame) in zip(hitTargets, touchFrames) {
            hitTarget.frame = frame
        }
    }
}
