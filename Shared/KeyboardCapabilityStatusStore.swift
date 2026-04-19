import Foundation

struct KeyboardCapabilityStatus: Codable, Equatable {
    var lastConfirmedFullAccessAt: Date?
}

final class KeyboardCapabilityStatusStore {
    private enum Keys {
        static let status = "keyboard.capabilities.v1"
    }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.defaults = defaults
    }

    func load() -> KeyboardCapabilityStatus {
        guard
            let defaults,
            let data = defaults.data(forKey: Keys.status),
            let status = try? JSONDecoder().decode(KeyboardCapabilityStatus.self, from: data)
        else {
            return KeyboardCapabilityStatus()
        }

        return status
    }

    func confirmFullAccessNow() {
        guard let defaults else {
            return
        }

        guard
            let data = try? JSONEncoder().encode(
                KeyboardCapabilityStatus(lastConfirmedFullAccessAt: Date())
            )
        else {
            return
        }

        defaults.set(data, forKey: Keys.status)
    }
}
