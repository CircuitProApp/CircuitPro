import CoreGraphics

struct Handle: Hashable {
    enum Kind: Hashable {
        case circleRadius
        case lineStart, lineEnd
        case rectTopLeft, rectTopRight,
                 rectBottomRight, rectBottomLeft
    }

    let kind: Kind
    let position: CGPoint
}
