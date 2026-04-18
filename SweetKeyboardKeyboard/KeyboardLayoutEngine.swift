import CoreGraphics
import Foundation

struct KeyboardRowSpec {
    let items: [KeyboardKeySpec]
}

struct KeyboardKeySpec {
    let kind: KeyboardKeyKind
    let width: KeyboardKeyWidth
}

enum KeyboardKeyKind {
    case character(String)
    case shift
    case backspace
    case space
    case symbolToggle
    case letterToggle
    case primaryAction
    case systemText(String)
    case systemSymbol(String)
    case cursor(offset: Int, symbolName: String)
}

struct KeyboardKeyWidth {
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
    private let symbolPunctuationRow = [".", ",", "?", "!", "'"]

    private let rowOne = Array("qwertyuiop").map(String.init)
    private let rowTwo = Array("asdfghjkl").map(String.init)
    private let rowThree = Array("zxcvbnm").map(String.init)

    func letterRows(isShiftEnabled: Bool, isEmailField: Bool) -> [KeyboardRowSpec] {
        let letters = resolvedLetterRows(isShiftEnabled: isShiftEnabled)

        return [
            makeCharacterRow(numberRow),
            makeCharacterRow(letters[0]),
            makeCharacterRow(letters[1]),
            KeyboardRowSpec(
                items: [
                    KeyboardKeySpec(kind: .shift, width: .units(1.5))
                ] +
                letters[2].map { KeyboardKeySpec(kind: .character($0), width: .normal) } +
                [
                    KeyboardKeySpec(kind: .backspace, width: .units(1.5))
                ]
            ),
            bottomLetterRow(isEmailField: isEmailField)
        ]
    }

    var symbolRows: [KeyboardRowSpec] {
        var rows = symbolCharacterRows.map(makeCharacterRow(_:))

        rows.append(
            KeyboardRowSpec(
                items: symbolPunctuationRow.map { KeyboardKeySpec(kind: .character($0), width: .normal) } +
                [
                    KeyboardKeySpec(kind: .cursor(offset: -1, symbolName: "arrow.left"), width: .units(1.725)),
                    KeyboardKeySpec(kind: .cursor(offset: 1, symbolName: "arrow.right"), width: .units(1.725)),
                    KeyboardKeySpec(kind: .backspace, width: .units(1.5))
                ]
            )
        )

        rows.append(
            KeyboardRowSpec(
                items: [
                    KeyboardKeySpec(kind: .letterToggle, width: .units(1.35)),
                    KeyboardKeySpec(kind: .space, width: .units(4.8)),
                    KeyboardKeySpec(kind: .primaryAction, width: .units(1.6))
                ]
            )
        )

        return rows
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

    private func makeCharacterRow(_ titles: [String]) -> KeyboardRowSpec {
        KeyboardRowSpec(
            items: titles.map { KeyboardKeySpec(kind: .character($0), width: .normal) }
        )
    }

    private func bottomLetterRow(isEmailField: Bool) -> KeyboardRowSpec {
        var items = [
            KeyboardKeySpec(kind: .symbolToggle, width: .units(1.25)),
            KeyboardKeySpec(kind: .character(","), width: .units(0.56)),
            KeyboardKeySpec(kind: .character("."), width: .units(0.56)),
            KeyboardKeySpec(kind: .character("?"), width: .units(0.56))
        ]

        if isEmailField {
            items.append(KeyboardKeySpec(kind: .space, width: .units(2.5)))
            items.append(KeyboardKeySpec(kind: .character("@"), width: .units(0.7)))
        } else {
            items.append(KeyboardKeySpec(kind: .space, width: .units(3.2)))
        }

        items.append(KeyboardKeySpec(kind: .primaryAction, width: .units(1.6)))

        return KeyboardRowSpec(items: items)
    }
}
