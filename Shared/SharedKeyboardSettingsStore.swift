import Foundation

struct SharedKeyboardSettings: Codable, Equatable {
    var clipboardModeEnabled: Bool = false
    var keyHapticsEnabled: Bool = false
    var autoCapitalizationEnabled: Bool = true
    var symbolLockEnabled: Bool = false

    private enum CodingKeys: String, CodingKey {
        case clipboardModeEnabled
        case keyHapticsEnabled
        case autoCapitalizationEnabled
        case symbolLockEnabled
    }

    init(
        clipboardModeEnabled: Bool = false,
        keyHapticsEnabled: Bool = false,
        autoCapitalizationEnabled: Bool = true,
        symbolLockEnabled: Bool = false
    ) {
        self.clipboardModeEnabled = clipboardModeEnabled
        self.keyHapticsEnabled = keyHapticsEnabled
        self.autoCapitalizationEnabled = autoCapitalizationEnabled
        self.symbolLockEnabled = symbolLockEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clipboardModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .clipboardModeEnabled) ?? false
        keyHapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyHapticsEnabled) ?? false
        autoCapitalizationEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoCapitalizationEnabled) ?? true
        symbolLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .symbolLockEnabled) ?? false
    }
}

final class SharedKeyboardSettingsStore {
    private enum Keys {
        static let settings = "keyboard.settings.v1"
    }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.defaults = defaults
    }

    func load() -> SharedKeyboardSettings {
        guard
            let defaults,
            let data = defaults.data(forKey: Keys.settings),
            let settings = try? JSONDecoder().decode(SharedKeyboardSettings.self, from: data)
        else {
            return SharedKeyboardSettings()
        }

        return settings
    }

    func setClipboardModeEnabled(_ isEnabled: Bool) {
        var settings = load()
        settings.clipboardModeEnabled = isEnabled
        save(settings)
    }

    func setKeyHapticsEnabled(_ isEnabled: Bool) {
        var settings = load()
        settings.keyHapticsEnabled = isEnabled
        save(settings)
    }

    func setAutoCapitalizationEnabled(_ isEnabled: Bool) {
        var settings = load()
        settings.autoCapitalizationEnabled = isEnabled
        save(settings)
    }

    func setSymbolLockEnabled(_ isEnabled: Bool) {
        var settings = load()
        settings.symbolLockEnabled = isEnabled
        save(settings)
    }

    private func save(_ settings: SharedKeyboardSettings) {
        guard let defaults else {
            return
        }

        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(data, forKey: Keys.settings)
    }
}
