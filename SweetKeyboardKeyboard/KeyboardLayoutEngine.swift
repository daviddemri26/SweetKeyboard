import Foundation

struct KeyboardLayoutEngine {
    let numberRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    private let rowOne = Array("qwertyuiop").map(String.init)
    private let rowTwo = Array("asdfghjkl").map(String.init)
    private let rowThree = Array("zxcvbnm").map(String.init)

    func letterRows(isShiftEnabled: Bool) -> [[String]] {
        let rows = [rowOne, rowTwo, rowThree]
        guard isShiftEnabled else {
            return rows
        }

        return rows.map { row in
            row.map { $0.uppercased() }
        }
    }
}
