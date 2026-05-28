import Foundation

enum SystemClipboardAction: String, Codable, CaseIterable, Equatable, Hashable {
    case pasteAndSave
    case importOnly
    case pasteOnly

    var title: String {
        switch self {
        case .pasteAndSave:
            return "Import and Paste"
        case .importOnly:
            return "Import"
        case .pasteOnly:
            return "Paste"
        }
    }

    var detail: String {
        switch self {
        case .pasteAndSave:
            return "Import text from the native iPhone Clipboard into SweetKeyboard Clipboard and paste it into the active field."
        case .importOnly:
            return "Import text from the native iPhone Clipboard into SweetKeyboard Clipboard."
        case .pasteOnly:
            return "Paste text from the native iPhone Clipboard into the active field."
        }
    }

    var symbolNames: [String] {
        switch self {
        case .pasteAndSave:
            return ["doc.on.clipboard.fill", "doc.on.clipboard", "square.and.arrow.down.on.square"]
        case .importOnly:
            return ["square.and.arrow.down.on.square"]
        case .pasteOnly:
            return ["doc.on.clipboard", "clipboard"]
        }
    }
}

struct SharedKeyboardSettings: Codable, Equatable {
    var clipboardModeEnabled: Bool = false
    var keyHapticsEnabled: Bool = false
    var autoCapitalizationEnabled: Bool = true
    var symbolLockEnabled: Bool = false
    var openClipboardAfterCopyEnabled: Bool = false
    var systemClipboardActions: Set<SystemClipboardAction> = [.pasteAndSave]
    var cursorSwipeEnabled: Bool = true
    var forwardDeleteWithShiftEnabled: Bool = false

    private enum CodingKeys: String, CodingKey {
        case clipboardModeEnabled
        case keyHapticsEnabled
        case autoCapitalizationEnabled
        case symbolLockEnabled
        case openClipboardAfterCopyEnabled
        case systemClipboardActions
        case systemClipboardActionMode
        case cursorSwipeEnabled
        case forwardDeleteWithShiftEnabled
    }

    private enum LegacySystemClipboardActionMode: String, Codable {
        case pasteAndSave
        case importOnly
        case pasteOnly
        case importAndPaste

        var actions: Set<SystemClipboardAction> {
            switch self {
            case .pasteAndSave:
                return [.pasteAndSave]
            case .importOnly:
                return [.importOnly]
            case .pasteOnly:
                return [.pasteOnly]
            case .importAndPaste:
                return [.importOnly, .pasteOnly]
            }
        }
    }

    init(
        clipboardModeEnabled: Bool = false,
        keyHapticsEnabled: Bool = false,
        autoCapitalizationEnabled: Bool = true,
        symbolLockEnabled: Bool = false,
        openClipboardAfterCopyEnabled: Bool = false,
        systemClipboardActions: Set<SystemClipboardAction> = [.pasteAndSave],
        cursorSwipeEnabled: Bool = true,
        forwardDeleteWithShiftEnabled: Bool = false
    ) {
        self.clipboardModeEnabled = clipboardModeEnabled
        self.keyHapticsEnabled = keyHapticsEnabled
        self.autoCapitalizationEnabled = autoCapitalizationEnabled
        self.symbolLockEnabled = symbolLockEnabled
        self.openClipboardAfterCopyEnabled = openClipboardAfterCopyEnabled
        self.systemClipboardActions = systemClipboardActions
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
        if let actions = try container.decodeIfPresent(Set<SystemClipboardAction>.self, forKey: .systemClipboardActions) {
            systemClipboardActions = actions
        } else if let legacyMode = try? container.decode(
            LegacySystemClipboardActionMode.self,
            forKey: .systemClipboardActionMode
        ) {
            systemClipboardActions = legacyMode.actions
        } else {
            systemClipboardActions = [.pasteAndSave]
        }
        cursorSwipeEnabled = try container.decodeIfPresent(Bool.self, forKey: .cursorSwipeEnabled) ?? true
        forwardDeleteWithShiftEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .forwardDeleteWithShiftEnabled
        ) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clipboardModeEnabled, forKey: .clipboardModeEnabled)
        try container.encode(keyHapticsEnabled, forKey: .keyHapticsEnabled)
        try container.encode(autoCapitalizationEnabled, forKey: .autoCapitalizationEnabled)
        try container.encode(symbolLockEnabled, forKey: .symbolLockEnabled)
        try container.encode(openClipboardAfterCopyEnabled, forKey: .openClipboardAfterCopyEnabled)
        try container.encode(systemClipboardActions.sortedForDisplay, forKey: .systemClipboardActions)
        try container.encode(cursorSwipeEnabled, forKey: .cursorSwipeEnabled)
        try container.encode(forwardDeleteWithShiftEnabled, forKey: .forwardDeleteWithShiftEnabled)
    }
}

extension Set where Element == SystemClipboardAction {
    var sortedForDisplay: [SystemClipboardAction] {
        SystemClipboardAction.allCases.filter { contains($0) }
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

    func setSystemClipboardActions(_ actions: Set<SystemClipboardAction>) {
        var settings = load()
        settings.systemClipboardActions = actions
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
