import Foundation

struct KeyboardCapabilityStatus: Codable, Equatable {
    var lastConfirmedFullAccessAt: Date?

    init(
        lastConfirmedFullAccessAt: Date? = nil
    ) {
        self.lastConfirmedFullAccessAt = lastConfirmedFullAccessAt
    }

    private enum CodingKeys: String, CodingKey {
        case lastConfirmedFullAccessAt
        case isFullAccessEnabled
        case lastUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let confirmationDate = try container.decodeIfPresent(Date.self, forKey: .lastConfirmedFullAccessAt)
        let legacyIsFullAccessEnabled = try container.decodeIfPresent(Bool.self, forKey: .isFullAccessEnabled) ?? false
        let legacyUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)

        if let confirmationDate {
            lastConfirmedFullAccessAt = confirmationDate
        } else if legacyIsFullAccessEnabled {
            lastConfirmedFullAccessAt = legacyUpdatedAt
        } else {
            lastConfirmedFullAccessAt = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lastConfirmedFullAccessAt, forKey: .lastConfirmedFullAccessAt)
    }
}

final class KeyboardCapabilityStatusStore {
    private enum Keys {
        static let status = "keyboard.capabilities.v1"
        static let fileName = "keyboard-capabilities-status.json"
    }

    private let defaults: UserDefaults?
    private let localFallbackDefaults: UserDefaults?
    private let fileURL: URL?

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier),
        fileURL: URL? = KeyboardCapabilityStatusStore.defaultFileURL(),
        localFallbackDefaults: UserDefaults? = nil
    ) {
        self.defaults = defaults
        self.fileURL = fileURL
        self.localFallbackDefaults = localFallbackDefaults
    }

    func load() -> KeyboardCapabilityStatus {
        if let status = loadFromFile() {
            return status
        }

        if let status = loadFromDefaults(defaults) {
            persist(status)
            return status
        }

        if let status = loadFromDefaults(localFallbackDefaults) {
            return status
        }

        return KeyboardCapabilityStatus()
    }

    func confirmFullAccessNow(at date: Date = Date()) {
        persist(KeyboardCapabilityStatus(lastConfirmedFullAccessAt: date))
    }

    private func loadFromFile() -> KeyboardCapabilityStatus? {
        guard
            let fileURL,
            let data = try? Data(contentsOf: fileURL),
            let status = try? JSONDecoder().decode(KeyboardCapabilityStatus.self, from: data)
        else {
            return nil
        }

        return status
    }

    private func loadFromDefaults(_ defaults: UserDefaults?) -> KeyboardCapabilityStatus? {
        guard
            let defaults,
            let data = defaults.data(forKey: Keys.status),
            let status = try? JSONDecoder().decode(KeyboardCapabilityStatus.self, from: data)
        else {
            return nil
        }

        return status
    }

    private func persist(_ status: KeyboardCapabilityStatus) {
        guard let data = try? JSONEncoder().encode(status) else {
            return
        }

        defaults?.set(data, forKey: Keys.status)
        localFallbackDefaults?.set(data, forKey: Keys.status)

        guard let fileURL else {
            return
        }

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(Keys.fileName)
    }
}

enum KeyboardCapabilityStatusTextFormatter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func historySummary(for status: KeyboardCapabilityStatus) -> String {
        historyLine(for: status)
    }

    static func appSettingsSummary(for status: KeyboardCapabilityStatus) -> String {
        """
        Clipboard tools only appear in the keyboard when Full Access is currently available.
        \(historyLine(for: status))
        """
    }

    static func keyboardSettingsSummary(
        isFullAccessCurrentlyAvailable: Bool,
        status: KeyboardCapabilityStatus,
        isClipboardModeEnabled: Bool
    ) -> String? {
        _ = status
        _ = isClipboardModeEnabled

        if isFullAccessCurrentlyAvailable {
            return nil
        }

        return "Please enable Full Access for SweetKeyboard in Settings app."
    }

    private static func historyLine(for status: KeyboardCapabilityStatus) -> String {
        guard let confirmationDate = status.lastConfirmedFullAccessAt else {
            return "Full Access has never been confirmed on this device."
        }

        return "Last confirmed on \(formatted(confirmationDate))."
    }

    private static func formatted(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
