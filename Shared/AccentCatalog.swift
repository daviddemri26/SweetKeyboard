import Foundation

enum LetterKeyboardRow: Int, Equatable {
    case number = 0
    case top = 1
    case middle = 2
    case bottom = 3
    case action = 4
}

struct AccentReplacementState: Equatable {
    let baseLetter: String
    let sourceRow: LetterKeyboardRow
    let replacedRow: LetterKeyboardRow
    let variants: [String]
    let isUppercase: Bool
}

enum AccentCatalog {
    private static let variantsByLetter: [String: [String]] = [
        "a": ["à", "â", "ä", "á", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "e": ["é", "è", "ê", "ë", "ē"],
        "i": ["î", "ï", "í", "ì", "ī"],
        "n": ["ñ", "ń", "ň"],
        "o": ["ô", "ö", "ó", "ò", "œ", "õ", "ø", "ō"],
        "u": ["ù", "û", "ü", "ú", "ū"],
        "y": ["ÿ", "ý"]
    ]
    private static let periodVariants = ["…", ":", "•", "@", "!", "?", ","]

    private static let topRowLetters = Set("qwertyuiop".map(String.init))
    private static let middleRowLetters = Set("asdfghjkl".map(String.init))
    private static let bottomRowLetters = Set("zxcvbnm".map(String.init))

    static func replacementState(for displayedLetter: String, isUppercase: Bool) -> AccentReplacementState? {
        let normalizedLetter = displayedLetter.lowercased()

        if normalizedLetter == "." {
            return AccentReplacementState(
                baseLetter: ".",
                sourceRow: .action,
                replacedRow: .bottom,
                variants: periodVariants,
                isUppercase: false
            )
        }

        guard
            let variants = variantsByLetter[normalizedLetter],
            let sourceRow = sourceRow(for: normalizedLetter),
            let replacedRow = LetterKeyboardRow(rawValue: sourceRow.rawValue - 1)
        else {
            return nil
        }

        let resolvedVariants = isUppercase
            ? variants.map { $0.uppercased() }
            : variants

        return AccentReplacementState(
            baseLetter: isUppercase ? normalizedLetter.uppercased() : normalizedLetter,
            sourceRow: sourceRow,
            replacedRow: replacedRow,
            variants: resolvedVariants,
            isUppercase: isUppercase
        )
    }

    private static func sourceRow(for normalizedLetter: String) -> LetterKeyboardRow? {
        if topRowLetters.contains(normalizedLetter) {
            return .top
        }

        if middleRowLetters.contains(normalizedLetter) {
            return .middle
        }

        if bottomRowLetters.contains(normalizedLetter) {
            return .bottom
        }

        return nil
    }
}
