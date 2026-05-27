import Foundation

enum SystemClipboardActionMode: String, Codable, CaseIterable, Equatable, Hashable {
    case pasteAndSave
    case importOnly
    case pasteOnly
    case importAndPaste

    var title: String {
        switch self {
        case .pasteAndSave:
            return "Paste & Save"
        case .importOnly:
            return "Import Only"
        case .pasteOnly:
            return "Paste Only"
        case .importAndPaste:
            return "Import + Paste"
        }
    }
}

struct SharedKeyboardSettings: Codable, Equatable {
    var clipboardModeEnabled: Bool = false
    var keyHapticsEnabled: Bool = false
    var autoCapitalizationEnabled: Bool = true
    var symbolLockEnabled: Bool = false
    var openClipboardAfterCopyEnabled: Bool = false
    var systemClipboardActionMode: SystemClipboardActionMode = .pasteAndSave
    var cursorSwipeEnabled: Bool = true
    var forwardDeleteWithShiftEnabled: Bool = false

    private enum CodingKeys: String, CodingKey {
        case clipboardModeEnabled
        case keyHapticsEnabled
        case autoCapitalizationEnabled
        case symbolLockEnabled
        case openClipboardAfterCopyEnabled
        case systemClipboardActionMode
        case cursorSwipeEnabled
        case forwardDeleteWithShiftEnabled
    }

    init(
        clipboardModeEnabled: Bool = false,
        keyHapticsEnabled: Bool = false,
        autoCapitalizationEnabled: Bool = true,
        symbolLockEnabled: Bool = false,
        openClipboardAfterCopyEnabled: Bool = false,
        systemClipboardActionMode: SystemClipboardActionMode = .pasteAndSave,
        cursorSwipeEnabled: Bool = true,
        forwardDeleteWithShiftEnabled: Bool = false
    ) {
        self.clipboardModeEnabled = clipboardModeEnabled
        self.keyHapticsEnabled = keyHapticsEnabled
        self.autoCapitalizationEnabled = autoCapitalizationEnabled
        self.symbolLockEnabled = symbolLockEnabled
        self.openClipboardAfterCopyEnabled = openClipboardAfterCopyEnabled
        self.systemClipboardActionMode = systemClipboardActionMode
        self.cursorSwipeEnabled = cursorSwipeEnabled
        self.forwardDeleteWithShiftEnabled = forwardDeleteWithShiftEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clipboardModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .clipboardModeEnabled) ?? false
        keyHapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyHapticsEnabled) ?? false
        autoCapitalizationEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoCapitalizationEnabled) ?? true
        symbolLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .symbolLockEnabled) ?? false
        openClipboardAfterCopyEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .openClipboardAfterCopyEnabled
        ) ?? false
        systemClipboardActionMode = (try? container.decode(
            SystemClipboardActionMode.self,
            forKey: .systemClipboardActionMode
        )) ?? .pasteAndSave
        cursorSwipeEnabled = try container.decodeIfPresent(Bool.self, forKey: .cursorSwipeEnabled) ?? true
        forwardDeleteWithShiftEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .forwardDeleteWithShiftEnabled
        ) ?? false
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

    func setOpenClipboardAfterCopyEnabled(_ isEnabled: Bool) {
        var settings = load()
        settings.openClipboardAfterCopyEnabled = isEnabled
        save(settings)
    }

    func setSystemClipboardActionMode(_ mode: SystemClipboardActionMode) {
        var settings = load()
        settings.systemClipboardActionMode = mode
        save(settings)
    }

    func setCursorSwipeEnabled(_ isEnabled: Bool) {
        var settings = load()
        settings.cursorSwipeEnabled = isEnabled
        save(settings)
    }

    func setForwardDeleteWithShiftEnabled(_ isEnabled: Bool) {
        var settings = load()
        settings.forwardDeleteWithShiftEnabled = isEnabled
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
