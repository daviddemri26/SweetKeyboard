import UIKit

final class ClipboardPanelView: UIView {
    var onSelectText: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
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
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !items.isEmpty else {
            emptyLabel.isHidden = false
            return
        }

        emptyLabel.isHidden = true

        for rowStart in stride(from: 0, to: items.count, by: 3) {
            let row = makeRow()
            let rowItems = Array(items[rowStart..<min(rowStart + 3, items.count)])

            for item in rowItems {
                row.addArrangedSubview(makeItemButton(for: item))
            }

            while row.arrangedSubviews.count < 3 {
                row.addArrangedSubview(makeSpacerCell())
            }

            stackView.addArrangedSubview(row)
        }
    }

    private func setup() {
        backgroundColor = .clear

        addSubview(scrollView)
        addSubview(emptyLabel)
        scrollView.addSubview(stackView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = KeyboardMetrics.keyboardRowSpacing

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
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func applyTheme() {
        scrollView.backgroundColor = KeyboardTheme.panelBackground
        emptyLabel.textColor = KeyboardTheme.keyLabelColor
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

    private func makeItemButton(for item: ClipboardItem) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = item.text
        configuration.baseForegroundColor = KeyboardTheme.keyLabelColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        configuration.background.backgroundColor = KeyboardTheme.panelItemBackground
        configuration.background.cornerRadius = KeyboardMetrics.panelItemCornerRadius
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.contentVerticalAlignment = .top
        button.titleLabel?.numberOfLines = 3
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.textAlignment = .left
        button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
        button.addAction(UIAction { [weak self] _ in
            self?.onSelectText?(item.text)
        }, for: .touchUpInside)
        return button
    }

    private func makeSpacerCell() -> UIView {
        let spacer = UIView()
        spacer.backgroundColor = .clear
        spacer.heightAnchor.constraint(equalTo: spacer.widthAnchor).isActive = true
        return spacer
    }
}
