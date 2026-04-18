import UIKit

final class ClipboardPanelView: UIView {
    var onSelectText: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Clipboard history is empty"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
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

        for item in items {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = item.text
            configuration.baseForegroundColor = .label
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            configuration.background.backgroundColor = .secondarySystemFill
            configuration.background.cornerRadius = 12
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.numberOfLines = 3
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.addAction(UIAction { [weak self] _ in
                self?.onSelectText?(item.text)
            }, for: .touchUpInside)
            stackView.addArrangedSubview(button)
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
        stackView.spacing = 8

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
}
