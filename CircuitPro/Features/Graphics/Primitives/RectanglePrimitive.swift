import AppKit

struct RectanglePrimitive: GraphicPrimitive {
    let uuid: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var color: SDColor
    var filled: Bool
    var cornerRadius: CGFloat = 0
    
    func handles() -> [Handle] {
        let halfW = size.width / 2
        let halfH = size.height / 2

        let topLeft = CGPoint(x: position.x - halfW, y: position.y + halfH)
        let topRight = CGPoint(x: position.x + halfW, y: position.y + halfH)
        let bottomRight = CGPoint(x: position.x + halfW, y: position.y - halfH)
        let bottomLeft = CGPoint(x: position.x - halfW, y: position.y - halfH)

        return [
            Handle(
                kind: .rectTopLeft,
                position: rotate(point: topLeft, around: position, by: rotation)
            ),
            Handle(
                kind: .rectTopRight,
                position: rotate(point: topRight, around: position, by: rotation)
            ),
            Handle(
                kind: .rectBottomRight,
                position: rotate(point: bottomRight, around: position, by: rotation)
            ),
            Handle(
                kind: .rectBottomLeft,
                position: rotate(point: bottomLeft, around: position, by: rotation)
            )
        ]
    }
    mutating func updateHandle(
        _ kind: Handle.Kind,
        to dragPosition: CGPoint,
        opposite oppositeCorner: CGPoint?
    ) {
        guard let oppositeCorner = oppositeCorner else { return }

        // Accept only corner kinds
        switch kind {
        case .rectTopLeft, .rectTopRight,
             .rectBottomRight, .rectBottomLeft:

            // Unit vectors along the rectangle’s local X and Y axes
            let unitX = CGVector(dx: cos(rotation), dy: sin(rotation))
            let unitY = CGVector(dx: -sin(rotation), dy: cos(rotation))

            // Vector from opposite corner to dragged corner (world space)
            let dragVector = CGVector(
                dx: dragPosition.x - oppositeCorner.x,
                dy: dragPosition.y - oppositeCorner.y
            )

            // Width and height are projections of dragVector onto local axes
            let projectedWidth = abs(dragVector.dx * unitX.dx + dragVector.dy * unitX.dy)
            let projectedHeight = abs(dragVector.dx * unitY.dx + dragVector.dy * unitY.dy)

            size = CGSize(
                width: max(projectedWidth, 1),
                height: max(projectedHeight, 1)
            )

            position = CGPoint(
                x: (dragPosition.x + oppositeCorner.x) * 0.5,
                y: (dragPosition.y + oppositeCorner.y) * 0.5
            )

        default:
            break
        }
    }
    func makePath(offset: CGPoint = .zero) -> CGPath {
        // 1. Build an *unrotated* rectangle whose center is position + offset
        let center = CGPoint(
            x: offset.x + position.x,
            y: offset.y + position.y
        )

        let frame = CGRect(
            x: center.x - size.width  * 0.5,
            y: center.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )

        let path = CGMutablePath()
        path.addRect(frame)

        // 2. Apply the primitive’s rotation about the rectangle center
        var transform = CGAffineTransform.identity
            .translatedBy(x: center.x, y: center.y)
            .rotated(by: rotation)
            .translatedBy(x: -center.x, y: -center.y)

        return path.copy(using: &transform) ?? path
    }
}
