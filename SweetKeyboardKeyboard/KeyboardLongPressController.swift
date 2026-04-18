import UIKit

final class KeyboardLongPressController {
    private let delay: TimeInterval

    private weak var activeButton: UIButton?
    private var timer: Timer?
    private(set) var didTrigger = false

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func begin(on button: UIButton, action: @escaping () -> Void) {
        stop()

        activeButton = button
        didTrigger = false

        timer = Timer(timeInterval: delay, repeats: false) { [weak self, weak button] _ in
            guard let self, let button, self.activeButton === button else {
                return
            }

            self.didTrigger = true
            action()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func completeTap(on button: UIButton, action: () -> Void) -> Bool {
        defer {
            stop()
        }

        guard activeButton === button, !didTrigger else {
            return false
        }

        action()
        return true
    }

    func wasTriggered(on button: UIButton) -> Bool {
        activeButton === button && didTrigger
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        activeButton = nil
        didTrigger = false
    }
}
