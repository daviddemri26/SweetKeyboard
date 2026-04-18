import UIKit

final class KeyboardFeedbackPresenter {
    private weak var label: UILabel?

    init(label: UILabel) {
        self.label = label
    }

    func show(_ message: String) {
        guard let label else {
            return
        }

        label.layer.removeAllAnimations()
        label.text = message
        label.alpha = 1

        UIView.animate(withDuration: 0.25, delay: 0.8, options: [.curveEaseOut]) {
            label.alpha = 0
        }
    }
}
