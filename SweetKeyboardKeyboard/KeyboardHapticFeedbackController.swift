import UIKit

final class KeyboardHapticFeedbackController {
    private let impactGenerator: UIImpactFeedbackGenerator = {
        if #available(iOS 13.0, *) {
            return UIImpactFeedbackGenerator(style: .rigid)
        } else {
            return UIImpactFeedbackGenerator(style: .light)
        }
    }()
    private var isEnabled = false

    init() {
        impactGenerator.prepare()
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled

        if isEnabled {
            impactGenerator.prepare()
        }
    }

    func triggerKeyPress() {
        guard isEnabled else {
            return
        }

        if #available(iOS 13.0, *) {
            impactGenerator.impactOccurred(intensity: 0.92)
        } else {
            impactGenerator.impactOccurred()
        }

        impactGenerator.prepare()
    }
}
