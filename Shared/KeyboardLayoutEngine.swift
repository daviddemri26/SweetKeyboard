import CoreGraphics
import Foundation

struct KeyboardRowSpec: Equatable {
    let items: [KeyboardKeySpec]
}

struct KeyboardKeySpec: Equatable {
    let kind: KeyboardKeyKind
    let width: KeyboardKeyWidth
}

enum KeyboardKeyKind: Equatable {
    case character(String)
    case shift
    case backspace
    case space
    case symbolToggle
    case letterToggle
    case primaryAction
    case cursor(offset: Int, symbolName: String)
    case inlineSettings
    case symbolLock(isEnabled: Bool)
    case nonLetterLayoutToggle(style: NonLetterLayoutToggleStyle, target: SequencedKeyboardLayoutTarget)
}

enum NonLetterLayoutToggleStyle: Equatable {
    case emoji
    case symbols
}

struct KeyboardKeyWidth: Equatable {
    let share: CGFloat
    let minimumUnits: CGFloat

    static let normal = Self(share: 1, minimumUnits: 1)

    static func units(_ value: CGFloat) -> Self {
        Self(share: value, minimumUnits: value)
    }

    static func custom(share: CGFloat, minimumUnits: CGFloat) -> Self {
        Self(share: share, minimumUnits: minimumUnits)
    }
}

struct KeyboardLayoutEngine {
    private let numberRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let symbolCharacterRows = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
    ]
    private let emojiCharacterRows = [
        ["😀", "😃", "😄", "🙂", "😉", "😎", "🤔", "😅", "😂", "🤣"],
        ["😭", "😍", "😘", "🙏", "👍", "👎", "👏", "🙌", "✅", "💯"],
        ["🔥", "⚠️", "⚡", "🎉", "🚀", "❤️", "🩷", "💛", "💚", "💙"]
    ]
    private let symbolPunctuationRow = [".", ",", "?", "!", "'"]

    private let rowOne = Array("qwertyuiop").map(String.init)
    private let rowTwo = Array("asdfghjkl'").map(String.init)
    private let rowThree = Array("zxcvbnm").map(String.init)

    func letterRows(
        isShiftEnabled: Bool,
        isEmailField: Bool,
        accentState: AccentReplacementState? = nil
    ) -> [KeyboardRowSpec] {
        let letters = resolvedLetterRows(isShiftEnabled: isShiftEnabled)
        let characterRows = resolvedCharacterRows(
            letters: letters,
            accentState: accentState
        )

        return [
            makeCharacterRow(characterRows[0]),
            makeCharacterRow(characterRows[1]),
            makeCharacterRow(characterRows[2]),
            KeyboardRowSpec(
                items: [
                    KeyboardKeySpec(kind: .shift, width: .units(1.5))
                ] +
                characterRows[3].map { KeyboardKeySpec(kind: .character($0), width: .normal) } +
                [
                    KeyboardKeySpec(kind: .backspace, width: .units(1.5))
                ]
            ),
            bottomLetterRow(isEmailField: isEmailField)
        ]
    }

    func symbolRows(showInlineSettingsKey: Bool, isSymbolLockEnabled: Bool) -> [KeyboardRowSpec] {
        var rows = symbolCharacterRows.map(makeCharacterRow(_:))
        rows.append(nonLetterPunctuationRow(showInlineSettingsKey: showInlineSettingsKey, isSymbolLockEnabled: isSymbolLockEnabled))
        rows.append(nonLetterBottomRow(toggleStyle: .emoji, target: .emoji))
        return rows
    }

    func emojiRows(showInlineSettingsKey: Bool, isSymbolLockEnabled: Bool) -> [KeyboardRowSpec] {
        var rows = emojiCharacterRows.map(makeCharacterRow(_:))
        rows.append(nonLetterPunctuationRow(showInlineSettingsKey: showInlineSettingsKey, isSymbolLockEnabled: isSymbolLockEnabled))
        rows.append(nonLetterBottomRow(toggleStyle: .symbols, target: .symbols))
        return rows
    }

    private func nonLetterPunctuationRow(
        showInlineSettingsKey: Bool,
        isSymbolLockEnabled: Bool
    ) -> KeyboardRowSpec {
        let punctuationItems: [KeyboardKeySpec]
        if showInlineSettingsKey {
            punctuationItems = [
                KeyboardKeySpec(kind: .inlineSettings, width: .units(1.1)),
                KeyboardKeySpec(kind: .symbolLock(isEnabled: isSymbolLockEnabled), width: .units(1.1)),
                KeyboardKeySpec(kind: .character("."), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character(","), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character("?"), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character("!"), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character("'"), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .cursor(offset: -1, symbolName: "arrowtriangle.left.fill"), width: .units(1.45)),
                KeyboardKeySpec(kind: .cursor(offset: 1, symbolName: "arrowtriangle.right.fill"), width: .units(1.45)),
                KeyboardKeySpec(kind: .backspace, width: .units(1.3))
            ]
        } else {
            punctuationItems = [
                KeyboardKeySpec(kind: .symbolLock(isEnabled: isSymbolLockEnabled), width: .units(1.1)),
                KeyboardKeySpec(kind: .character("."), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character(","), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character("?"), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character("!"), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .character("'"), width: .custom(share: 0.84, minimumUnits: 0.84)),
                KeyboardKeySpec(kind: .cursor(offset: -1, symbolName: "arrowtriangle.left.fill"), width: .units(1.45)),
                KeyboardKeySpec(kind: .cursor(offset: 1, symbolName: "arrowtriangle.right.fill"), width: .units(1.45)),
                KeyboardKeySpec(kind: .backspace, width: .units(1.3))
            ]
        }

        return KeyboardRowSpec(items: punctuationItems)
    }

    private func nonLetterBottomRow(
        toggleStyle: NonLetterLayoutToggleStyle,
        target: SequencedKeyboardLayoutTarget
    ) -> KeyboardRowSpec {
        KeyboardRowSpec(
            items: [
                KeyboardKeySpec(kind: .letterToggle, width: .units(1.35)),
                KeyboardKeySpec(kind: .nonLetterLayoutToggle(style: toggleStyle, target: target), width: .units(1.25)),
                KeyboardKeySpec(kind: .space, width: .units(3.55)),
                KeyboardKeySpec(kind: .primaryAction, width: .units(1.6))
            ]
        )
    }

    private func resolvedLetterRows(isShiftEnabled: Bool) -> [[String]] {
        let rows = [rowOne, rowTwo, rowThree]
        guard isShiftEnabled else {
            return rows
        }

        return rows.map { row in
            row.map { $0.uppercased() }
        }
    }

    private func resolvedCharacterRows(
        letters: [[String]],
        accentState: AccentReplacementState?
    ) -> [[String]] {
        var rows = [numberRow, letters[0], letters[1], letters[2]]

        if let accentState, accentState.replacedRow.rawValue < rows.count {
            rows[accentState.replacedRow.rawValue] = accentState.variants
        }

        return rows
    }

    private func makeCharacterRow(_ titles: [String]) -> KeyboardRowSpec {
        KeyboardRowSpec(
            items: titles.map { KeyboardKeySpec(kind: .character($0), width: .normal) }
        )
    }

    private func bottomLetterRow(isEmailField: Bool) -> KeyboardRowSpec {
        var items = [
            KeyboardKeySpec(kind: .symbolToggle, width: .units(1.25)),
            KeyboardKeySpec(kind: .space, width: .units(isEmailField ? 2.5 : 3.2)),
            KeyboardKeySpec(kind: .character("."), width: .units(0.56))
        ]

        if isEmailField {
            items.append(KeyboardKeySpec(kind: .character("@"), width: .units(0.7)))
        }

        items.append(KeyboardKeySpec(kind: .primaryAction, width: .units(1.6)))

        return KeyboardRowSpec(items: items)
    }
}
