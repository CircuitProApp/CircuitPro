import AppKit

struct CirclePrimitive: GraphicPrimitive {
    let id: UUID
    var position: CGPoint
    var radius: CGFloat
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var color: SDColor
    var filled: Bool
    func handles() -> [Handle] {
        let rawPoint = CGPoint(x: position.x + radius, y: position.y)
        let rotated = rotate(point: rawPoint, around: position, by: rotation)
        return [Handle(kind: .circleRadius, position: rotated)]
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to newPos: CGPoint
    ) {
        guard kind == .circleRadius else { return }

        // Calculate vector from center to new handle position
        let deltaX = newPos.x - position.x
        let deltaY = newPos.y - position.y

        // New radius is the distance
        radius = max(hypot(deltaX, deltaY), 1)

        // Rotation is the angle between center and handle
        rotation = atan2(deltaY, deltaX)
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to newPos: CGPoint,
        opposite _: CGPoint?
    ) {
        // just forward to the existing implementation
        updateHandle(kind, to: newPos)
    }
    func makePath(offset: CGPoint = .zero) -> CGPath {
            let center = CGPoint(
                x: offset.x + position.x,
                y: offset.y + position.y
            )
            let path = CGMutablePath()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: false
            )

            var transform = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: rotation)
                .translatedBy(x: -center.x, y: -center.y)
            return path.copy(using: &transform) ?? path
        }
}
