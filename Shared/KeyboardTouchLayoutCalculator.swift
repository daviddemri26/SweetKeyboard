import CoreGraphics

struct KeyboardTouchRowInsets: Equatable {
    let top: CGFloat
    let bottom: CGFloat
}

enum KeyboardTouchLayoutCalculator {
    static func rowInsets(
        rowIndex: Int,
        rowCount: Int,
        visualRowSpacing: CGFloat,
        bottomInset: CGFloat
    ) -> KeyboardTouchRowInsets {
        precondition(rowCount > 0, "rowCount must be greater than zero")
        precondition((0..<rowCount).contains(rowIndex), "rowIndex must describe an existing row")

        let halfSpacing = visualRowSpacing / 2

        return KeyboardTouchRowInsets(
            top: rowIndex == 0 ? 0 : halfSpacing,
            bottom: rowIndex == (rowCount - 1) ? bottomInset : halfSpacing
        )
    }

    static func rowHeight(keyHeight: CGFloat, insets: KeyboardTouchRowInsets) -> CGFloat {
        keyHeight + insets.top + insets.bottom
    }

    static func rowFrames(
        rowCount: Int,
        keyHeight: CGFloat,
        visualRowSpacing: CGFloat,
        bottomInset: CGFloat,
        width: CGFloat = 1
    ) -> [CGRect] {
        precondition(rowCount > 0, "rowCount must be greater than zero")

        var currentY: CGFloat = 0

        return (0..<rowCount).map { rowIndex in
            let insets = rowInsets(
                rowIndex: rowIndex,
                rowCount: rowCount,
                visualRowSpacing: visualRowSpacing,
                bottomInset: bottomInset
            )
            let frame = CGRect(
                x: 0,
                y: currentY,
                width: width,
                height: rowHeight(keyHeight: keyHeight, insets: insets)
            )
            currentY = frame.maxY
            return frame
        }
    }

    static func touchFrames(for visualFrames: [CGRect], in rowBounds: CGRect) -> [CGRect] {
        guard !visualFrames.isEmpty else {
            return []
        }

        return visualFrames.enumerated().map { index, frame in
            let minX = index == 0
                ? rowBounds.minX
                : midpoint(between: visualFrames[index - 1].maxX, and: frame.minX)
            let maxX = index == (visualFrames.count - 1)
                ? rowBounds.maxX
                : midpoint(between: frame.maxX, and: visualFrames[index + 1].minX)

            return CGRect(
                x: minX,
                y: rowBounds.minY,
                width: maxX - minX,
                height: rowBounds.height
            )
        }
    }

    private static func midpoint(between left: CGFloat, and right: CGFloat) -> CGFloat {
        (left + right) / 2
    }
}
