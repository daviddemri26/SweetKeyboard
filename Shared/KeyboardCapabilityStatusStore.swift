import Foundation

struct KeyboardCapabilityStatus: Codable, Equatable {
    var isFullAccessEnabled: Bool
    var lastUpdatedAt: Date?

    init(
        isFullAccessEnabled: Bool = false,
        lastUpdatedAt: Date? = nil
    ) {
        self.isFullAccessEnabled = isFullAccessEnabled
        self.lastUpdatedAt = lastUpdatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case isFullAccessEnabled
        case lastUpdatedAt
        case lastConfirmedFullAccessAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyConfirmationDate = try container.decodeIfPresent(Date.self, forKey: .lastConfirmedFullAccessAt)

        isFullAccessEnabled = try container.decodeIfPresent(Bool.self, forKey: .isFullAccessEnabled)
            ?? (legacyConfirmationDate != nil)
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
            ?? legacyConfirmationDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isFullAccessEnabled, forKey: .isFullAccessEnabled)
        try container.encodeIfPresent(lastUpdatedAt, forKey: .lastUpdatedAt)
    }
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

    func setFullAccessEnabled(_ isEnabled: Bool) {
        guard let defaults else {
            return
        }

        guard
            let data = try? JSONEncoder().encode(
                KeyboardCapabilityStatus(
                    isFullAccessEnabled: isEnabled,
                    lastUpdatedAt: Date()
                )
            )
        else {
            return
        }

        defaults.set(data, forKey: Keys.status)
    }
}
