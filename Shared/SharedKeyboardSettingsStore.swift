import Foundation

struct SharedKeyboardSettings: Codable, Equatable {
    var clipboardModeEnabled: Bool = false
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
