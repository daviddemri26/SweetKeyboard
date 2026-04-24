import UIKit

final class ClipboardPanelView: UIView {
    var onSelectText: ((String) -> Void)?
    var onOpenDetail: (() -> Void)?
    var onCloseDetail: (() -> Void)?
    var onTogglePin: ((ClipboardItem) -> ClipboardItem?)?
    var onDeleteItem: ((ClipboardItem) -> Void)?

    private enum Constants {
        static let columnCount = 3
        static let itemLineLimit = 4
        static let itemFontSize: CGFloat = 13
        static let itemVerticalPadding: CGFloat = 8
        static let itemHorizontalPadding: CGFloat = 10
        static let detailButtonWidth: CGFloat = 44
        static let detailButtonHeight: CGFloat = 34
        static let detailSpacing: CGFloat = 6
    }

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let detailContainer = UIView()
    private let detailTextView = UITextView()
    private let detailButtonStack = UIStackView()
    private let detailBackButton = KeyboardPressableButton(type: .custom)
    private let detailPasteButton = KeyboardPressableButton(type: .custom)
    private let detailPinButton = KeyboardPressableButton(type: .custom)
    private let detailDeleteButton = KeyboardPressableButton(type: .custom)
    private var detailItem: ClipboardItem?
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Clipboard history is empty"
        label.textAlignment = .center
        label.textColor = KeyboardTheme.keyLabelColor
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        registerForTraitChangesIfNeeded()
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(items: [ClipboardItem]) {
        detailItem = nil
        detailContainer.isHidden = true
        scrollView.isHidden = false
        scrollView.setContentOffset(.zero, animated: false)
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !items.isEmpty else {
            emptyLabel.isHidden = false
            return
        }

        emptyLabel.isHidden = true

        for rowStart in stride(from: 0, to: items.count, by: Constants.columnCount) {
            let row = makeRow()
            let rowItems = Array(items[rowStart..<min(rowStart + Constants.columnCount, items.count)])

            for item in rowItems {
                row.addArrangedSubview(makeItemButton(for: item))
            }

            while row.arrangedSubviews.count < Constants.columnCount {
                row.addArrangedSubview(makeSpacerCell())
            }

            stackView.addArrangedSubview(row)
        }
    }

    var isShowingDetail: Bool {
        detailItem != nil && detailContainer.isHidden == false
    }

    func selectedTextForCopyAction() -> String? {
        guard isShowingDetail else {
            return nil
        }

        return selectedDetailText()
    }

    private func setup() {
        backgroundColor = .clear

        addSubview(scrollView)
        addSubview(emptyLabel)
        addSubview(detailContainer)
        scrollView.addSubview(stackView)
        detailContainer.addSubview(detailTextView)
        detailContainer.addSubview(detailButtonStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        detailTextView.translatesAutoresizingMaskIntoConstraints = false
        detailButtonStack.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = KeyboardMetrics.keyboardRowSpacing
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: KeyboardMetrics.keyboardKeySpacing,
            leading: KeyboardMetrics.keyboardKeySpacing,
            bottom: KeyboardMetrics.keyboardKeySpacing,
            trailing: KeyboardMetrics.keyboardKeySpacing
        )

        detailContainer.isHidden = true
        detailButtonStack.axis = .vertical
        detailButtonStack.alignment = .fill
        detailButtonStack.spacing = Constants.detailSpacing
        detailButtonStack.addArrangedSubview(detailBackButton)
        detailButtonStack.addArrangedSubview(detailPasteButton)
        detailButtonStack.addArrangedSubview(detailPinButton)
        detailButtonStack.addArrangedSubview(detailDeleteButton)
        detailButtonStack.addArrangedSubview(UIView())

        configureDetailTextView()
        configureDetailIconButton(
            detailBackButton,
            symbolName: "chevron.left",
            accessibilityLabel: "Back",
            action: #selector(detailBackTapped)
        )
        configureDetailIconButton(
            detailPasteButton,
            symbolName: "square.filled.on.square",
            accessibilityLabel: "Paste",
            action: #selector(detailPasteTapped)
        )
        configureDetailIconButton(
            detailPinButton,
            symbolName: "heart",
            accessibilityLabel: "Pin",
            action: #selector(detailPinTapped)
        )
        configureDetailIconButton(
            detailDeleteButton,
            symbolName: "trash.fill",
            accessibilityLabel: "Delete",
            action: #selector(detailDeleteTapped)
        )

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            detailContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            detailContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            detailContainer.topAnchor.constraint(equalTo: topAnchor),
            detailContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            detailTextView.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: KeyboardMetrics.keyboardKeySpacing),
            detailTextView.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: KeyboardMetrics.keyboardKeySpacing),
            detailTextView.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor, constant: -KeyboardMetrics.keyboardKeySpacing),

            detailButtonStack.leadingAnchor.constraint(equalTo: detailTextView.trailingAnchor, constant: Constants.detailSpacing),
            detailButtonStack.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor, constant: -KeyboardMetrics.keyboardKeySpacing),
            detailButtonStack.topAnchor.constraint(equalTo: detailContainer.topAnchor, constant: KeyboardMetrics.keyboardKeySpacing),
            detailButtonStack.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor, constant: -KeyboardMetrics.keyboardKeySpacing),
            detailButtonStack.widthAnchor.constraint(equalToConstant: Constants.detailButtonWidth),

            detailBackButton.heightAnchor.constraint(equalToConstant: Constants.detailButtonHeight),
            detailPasteButton.heightAnchor.constraint(equalToConstant: Constants.detailButtonHeight),
            detailPinButton.heightAnchor.constraint(equalToConstant: Constants.detailButtonHeight),
            detailDeleteButton.heightAnchor.constraint(equalToConstant: Constants.detailButtonHeight)
        ])
    }

    private func applyTheme() {
        scrollView.backgroundColor = .clear
        emptyLabel.textColor = KeyboardTheme.keyLabelColor
        detailTextView.backgroundColor = KeyboardTheme.panelItemBackground
        detailTextView.textColor = KeyboardTheme.keyLabelColor
        detailTextView.tintColor = KeyboardTheme.keyLabelColor
        KeyboardTheme.applyChrome(
            to: detailBackButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: detailPasteButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: detailPinButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: detailDeleteButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
        updateDetailPinButton()
    }

    private func registerForTraitChangesIfNeeded() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.applyTheme()
            }
        }
    }

    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .fill
        row.distribution = .fillEqually
        row.spacing = KeyboardMetrics.keyboardKeySpacing
        return row
    }

    private func makeItemButton(for item: ClipboardItem) -> UIControl {
        let font = UIFont.systemFont(ofSize: Constants.itemFontSize, weight: .regular)
        let button = ClipboardItemButton(
            item: item,
            font: font,
            lineLimit: Constants.itemLineLimit,
            contentInsets: UIEdgeInsets(
                top: Constants.itemVerticalPadding,
                left: Constants.itemHorizontalPadding,
                bottom: Constants.itemVerticalPadding,
                right: Constants.itemHorizontalPadding
            )
        )
        button.heightAnchor.constraint(equalToConstant: itemCellHeight(for: font)).isActive = true
        button.addAction(
            UIAction { [weak self] _ in
                self?.onSelectText?(item.text)
            },
            for: .touchUpInside
        )

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(itemLongPressed(_:)))
        longPressRecognizer.minimumPressDuration = 0.45
        longPressRecognizer.cancelsTouchesInView = true
        button.addGestureRecognizer(longPressRecognizer)
        return button
    }

    private func makeSpacerCell() -> UIView {
        let spacer = UIView()
        spacer.backgroundColor = .clear
        spacer.heightAnchor.constraint(
            equalToConstant: itemCellHeight(for: UIFont.systemFont(ofSize: Constants.itemFontSize, weight: .regular))
        ).isActive = true
        return spacer
    }

    private func configureDetailTextView() {
        detailTextView.isEditable = false
        detailTextView.isSelectable = true
        detailTextView.isScrollEnabled = true
        detailTextView.alwaysBounceVertical = true
        detailTextView.font = .preferredFont(forTextStyle: .body)
        detailTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        detailTextView.layer.cornerRadius = KeyboardMetrics.keyCornerRadius
        detailTextView.layer.cornerCurve = .continuous
        detailTextView.clipsToBounds = true
    }

    private func configureDetailIconButton(
        _ button: KeyboardPressableButton,
        symbolName: String,
        accessibilityLabel: String,
        action: Selector
    ) {
        button.setTitle(nil, for: .normal)
        button.setSymbolConfigurations(
            normal: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .medium),
            highlighted: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .semibold)
        )
        button.setForegroundColors(
            normal: KeyboardTheme.keyLabelColor,
            highlighted: KeyboardTheme.keyLabelColor
        )
        button.setSymbolImage(UIImage(systemName: symbolName))
        button.setTapBounceEnabled(true)
        button.accessibilityLabel = accessibilityLabel
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func itemCellHeight(for font: UIFont) -> CGFloat {
        let lineHeight = ceil(font.lineHeight)
        return (lineHeight * CGFloat(Constants.itemLineLimit)) + (Constants.itemVerticalPadding * 2)
    }

    @objc private func itemLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let button = recognizer.view as? ClipboardItemButton else {
            return
        }

        let item = button.item
        detailItem = item
        detailTextView.text = item.text
        updateDetailPinButton()
        detailTextView.selectedRange = NSRange(location: 0, length: 0)
        detailTextView.setContentOffset(.zero, animated: false)
        scrollView.isHidden = true
        emptyLabel.isHidden = true
        detailContainer.isHidden = false
        onOpenDetail?()
    }

    @objc private func detailBackTapped() {
        closeDetail()
        onCloseDetail?()
    }

    @objc private func detailPasteTapped() {
        guard let detailItem else {
            return
        }

        if let selectedText = selectedDetailText(), !selectedText.isEmpty {
            onSelectText?(selectedText)
        } else {
            onSelectText?(detailItem.text)
        }
    }

    @objc private func detailPinTapped() {
        guard let detailItem,
              let updatedItem = onTogglePin?(detailItem) else {
            return
        }

        self.detailItem = updatedItem
        updateDetailPinButton()
    }

    @objc private func detailDeleteTapped() {
        guard let detailItem else {
            return
        }

        closeDetail()
        onDeleteItem?(detailItem)
    }

    private func closeDetail() {
        detailItem = nil
        detailTextView.text = ""
        detailContainer.isHidden = true
        scrollView.isHidden = false
        emptyLabel.isHidden = stackView.arrangedSubviews.isEmpty == false
        updateDetailPinButton()
    }

    private func updateDetailPinButton() {
        let isPinned = detailItem?.isPinned == true
        detailPinButton.setSymbolImage(UIImage(systemName: isPinned ? "heart.fill" : "heart"))
        detailPinButton.accessibilityLabel = isPinned ? "Unpin" : "Pin"
    }

    private func selectedDetailText() -> String? {
        guard detailTextView.selectedRange.length > 0,
              let textRange = Range(detailTextView.selectedRange, in: detailTextView.text) else {
            return nil
        }

        return String(detailTextView.text[textRange])
    }
}

private final class ClipboardItemButton: UIControl {
    let item: ClipboardItem

    private let label = UILabel()
    private let pinImageView = UIImageView(
        image: UIImage(
            systemName: "heart.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        )
    )
    private let normalBackgroundColor = KeyboardTheme.panelItemBackground
    private let highlightedBackgroundColor = KeyboardTheme.pressedBackground(for: .character)

    override var isHighlighted: Bool {
        didSet {
            updatePressedAppearance()
        }
    }

    init(item: ClipboardItem, font: UIFont, lineLimit: Int, contentInsets: UIEdgeInsets) {
        self.item = item
        super.init(frame: .zero)
        setup(font: font, lineLimit: lineLimit, contentInsets: contentInsets)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(font: UIFont, lineLimit: Int, contentInsets: UIEdgeInsets) {
        backgroundColor = normalBackgroundColor
        layer.cornerRadius = KeyboardMetrics.keyCornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        label.text = item.text
        label.font = font
        label.textColor = KeyboardTheme.keyLabelColor
        label.numberOfLines = lineLimit
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .left
        pinImageView.tintColor = KeyboardTheme.keyLabelColor.withAlphaComponent(0.72)
        pinImageView.contentMode = .scaleAspectFit
        pinImageView.isHidden = !item.isPinned

        addSubview(label)
        addSubview(pinImageView)
        label.translatesAutoresizingMaskIntoConstraints = false
        pinImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            label.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -contentInsets.bottom),
            pinImageView.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            pinImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            pinImageView.widthAnchor.constraint(equalToConstant: 12),
            pinImageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        isAccessibilityElement = true
        accessibilityLabel = item.text
        accessibilityTraits = .button
    }

    private func updatePressedAppearance() {
        backgroundColor = isHighlighted ? highlightedBackgroundColor : normalBackgroundColor
    }
}
