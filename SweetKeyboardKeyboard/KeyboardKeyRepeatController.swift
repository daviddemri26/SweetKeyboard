import UIKit

final class KeyboardKeyRepeatController {
    private let delay: TimeInterval
    private let repeatInterval: TimeInterval

    private weak var activeButton: UIButton?
    private var activeIdentifier: Int?
    private var delayTimer: Timer?
    private var repeatTimer: Timer?
    private(set) var didRepeat = false

    init(delay: TimeInterval, repeatInterval: TimeInterval) {
        self.delay = delay
        self.repeatInterval = repeatInterval
    }

    func begin(on button: UIButton, identifier: Int = 0, action: @escaping () -> Void) {
        stop()

        activeButton = button
        activeIdentifier = identifier
        didRepeat = false

        delayTimer = scheduleTimer(interval: delay, repeats: false) { [weak self, weak button] _ in
            guard let self, let button, self.isActive(button: button, identifier: identifier) else {
                return
            }

            self.didRepeat = true
            action()
            self.repeatTimer = self.scheduleTimer(interval: self.repeatInterval, repeats: true) { [weak self, weak button] _ in
                guard let self, let button, self.isActive(button: button, identifier: identifier) else {
                    return
                }

                action()
            }
        }
    }

    func completeTap(on button: UIButton, identifier: Int = 0, action: () -> Void) {
        defer {
            stop()
        }

        guard isActive(button: button, identifier: identifier), !didRepeat else {
            return
        }

        action()
    }

    func stop() {
        delayTimer?.invalidate()
        repeatTimer?.invalidate()
        delayTimer = nil
        repeatTimer = nil
        activeButton = nil
        activeIdentifier = nil
        didRepeat = false
    }

    private func isActive(button: UIButton, identifier: Int) -> Bool {
        activeButton === button && activeIdentifier == identifier
    }

    private func scheduleTimer(
        interval: TimeInterval,
        repeats: Bool,
        handler: @escaping (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: handler)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
