import XCTest
@testable import SweetKeyboard

@MainActor
final class AccentFeatureTests: XCTestCase {
    func testAccentCatalogMapsLettersToReplacementRows() {
        XCTAssertEqual(AccentCatalog.replacementState(for: "e", isUppercase: false)?.replacedRow, .number)
        XCTAssertEqual(AccentCatalog.replacementState(for: "a", isUppercase: false)?.replacedRow, .top)
        XCTAssertEqual(AccentCatalog.replacementState(for: "n", isUppercase: false)?.replacedRow, .middle)
    }

    func testAccentCatalogUppercasesVariantsWhenShiftIsActive() {
        let state = AccentCatalog.replacementState(for: "E", isUppercase: true)

        XCTAssertEqual(state?.baseLetter, "E")
        XCTAssertEqual(state?.variants, ["É", "È", "Ê", "Ë", "Ē"])
    }

    func testAccentCatalogReturnsNilForUnsupportedLetters() {
        XCTAssertNil(AccentCatalog.replacementState(for: "q", isUppercase: false))
    }

    func testAccentCatalogReturnsBottomRowVariantsForPeriod() {
        let state = AccentCatalog.replacementState(for: ".", isUppercase: true)

        XCTAssertEqual(state?.baseLetter, ".")
        XCTAssertEqual(state?.sourceRow, .action)
        XCTAssertEqual(state?.replacedRow, .bottom)
        XCTAssertEqual(state?.variants, ["…", ":", "•", "@", "!", "?", ","])
        XCTAssertEqual(state?.isUppercase, false)
    }

    func testKeyboardLayoutEngineMatchesCurrentDefaultLayoutWithoutAccentState() {
        let engine = KeyboardLayoutEngine()

        let rows = engine.letterRows(isShiftEnabled: false, isEmailField: false)

        XCTAssertEqual(characterTitles(in: rows[0]), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        XCTAssertEqual(characterTitles(in: rows[1]), Array("qwertyuiop").map(String.init))
        XCTAssertEqual(characterTitles(in: rows[2]), Array("asdfghjkl'").map(String.init))
        XCTAssertEqual(characterTitles(in: rows[3]), Array("zxcvbnm").map(String.init))
        XCTAssertEqual(
            rows[4].items.map(\.kind),
            [.symbolToggle, .space, .character("."), .primaryAction]
        )
    }

    func testKeyboardLayoutEnginePlacesAtSymbolToTheRightOfPeriodInEmailFields() {
        let engine = KeyboardLayoutEngine()

        let rows = engine.letterRows(isShiftEnabled: false, isEmailField: true)

        XCTAssertEqual(
            rows[4].items.map(\.kind),
            [.symbolToggle, .space, .character("."), .character("@"), .primaryAction]
        )
    }

    func testKeyboardLayoutEngineReplacesOnlyTargetedRowForAccentState() {
        let engine = KeyboardLayoutEngine()
        let normalRows = engine.letterRows(isShiftEnabled: false, isEmailField: false)
        let accentState = AccentCatalog.replacementState(for: "n", isUppercase: false)!

        let accentedRows = engine.letterRows(
            isShiftEnabled: false,
            isEmailField: false,
            accentState: accentState
        )

        XCTAssertEqual(accentedRows[0], normalRows[0])
        XCTAssertEqual(accentedRows[1], normalRows[1])
        XCTAssertEqual(characterTitles(in: accentedRows[2]), ["ñ", "ń", "ň"])
        XCTAssertEqual(accentedRows[3], normalRows[3])
        XCTAssertEqual(accentedRows[4], normalRows[4])
    }

    func testKeyboardLayoutEngineShowsPeriodVariantsAboveBottomRow() {
        let engine = KeyboardLayoutEngine()
        let normalRows = engine.letterRows(isShiftEnabled: false, isEmailField: true)
        let accentState = AccentCatalog.replacementState(for: ".", isUppercase: false)!

        let accentedRows = engine.letterRows(
            isShiftEnabled: false,
            isEmailField: true,
            accentState: accentState
        )

        XCTAssertEqual(accentedRows[0], normalRows[0])
        XCTAssertEqual(accentedRows[1], normalRows[1])
        XCTAssertEqual(accentedRows[2], normalRows[2])
        XCTAssertEqual(characterTitles(in: accentedRows[3]), ["…", ":", "•", "@", "!", "?", ","])
        XCTAssertEqual(accentedRows[3].items.first?.kind, .shift)
        XCTAssertEqual(accentedRows[3].items.last?.kind, .backspace)
        XCTAssertEqual(accentedRows[4], normalRows[4])
    }

    func testKeyboardLayoutEngineReturnsToDefaultLayoutAfterAccentStateClears() {
        let engine = KeyboardLayoutEngine()
        let normalRows = engine.letterRows(isShiftEnabled: true, isEmailField: true)
        let accentState = AccentCatalog.replacementState(for: "A", isUppercase: true)!

        _ = engine.letterRows(
            isShiftEnabled: true,
            isEmailField: true,
            accentState: accentState
        )
        let resetRows = engine.letterRows(isShiftEnabled: true, isEmailField: true)

        XCTAssertEqual(resetRows, normalRows)
    }

    func testKeyboardLayoutEngineAddsEmojiToggleToSymbolsBottomRow() {
        let engine = KeyboardLayoutEngine()

        let rows = engine.symbolRows(showInlineSettingsKey: false, isSymbolLockEnabled: false)

        XCTAssertEqual(
            rows[4].items.map(\.kind),
            [
                .letterToggle,
                .nonLetterLayoutToggle(style: .emoji, target: .emoji),
                .space,
                .primaryAction
            ]
        )
    }

    func testKeyboardLayoutEngineBuildsEmojiRowsWithSharedControls() {
        let engine = KeyboardLayoutEngine()

        let rows = engine.emojiRows(showInlineSettingsKey: true, isSymbolLockEnabled: true)

        XCTAssertEqual(characterTitles(in: rows[0]), ["😀", "😃", "😄", "🙂", "😉", "😎", "🤔", "😅", "😂", "🤣"])
        XCTAssertEqual(characterTitles(in: rows[1]), ["😭", "😍", "😘", "🙏", "👍", "👎", "👏", "🙌", "✅", "💯"])
        XCTAssertEqual(characterTitles(in: rows[2]), ["🔥", "⚠️", "⚡", "🎉", "🚀", "❤️", "🩷", "💛", "💚", "💙"])
        XCTAssertEqual(
            rows[3].items.map(\.kind),
            [
                .inlineSettings,
                .symbolLock(isEnabled: true),
                .character("."),
                .character(","),
                .character("?"),
                .character("!"),
                .character("'"),
                .cursor(offset: -1, symbolName: "arrowtriangle.left.fill"),
                .cursor(offset: 1, symbolName: "arrowtriangle.right.fill"),
                .backspace
            ]
        )
        XCTAssertEqual(
            rows[4].items.map(\.kind),
            [
                .letterToggle,
                .nonLetterLayoutToggle(style: .symbols, target: .symbols),
                .space,
                .primaryAction
            ]
        )
    }

    private func characterTitles(in row: KeyboardRowSpec) -> [String] {
        row.items.compactMap { item in
            guard case .character(let title) = item.kind else {
                return nil
            }

            return title
        }
    }
}
