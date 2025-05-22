import AppKit

struct LinePrimitive: GraphicPrimitive {
    let uuid: UUID
    var start: CGPoint
    var end: CGPoint
    var rotation: CGFloat = 0
    var strokeWidth: CGFloat
    var color: SDColor
    var filled: Bool = false

    var position: CGPoint {
        get {
            CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
        }
        set {
            let deltaX = newValue.x - position.x
            let deltaY = newValue.y - position.y
            start.x += deltaX
            start.y += deltaY
            end.x += deltaX
            end.y += deltaY
        }
    }
    func handles() -> [Handle] {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let rotatedStart = rotate(point: start, around: mid, by: rotation)
        let rotatedEnd = rotate(point: end, around: mid, by: rotation)
        return [
            Handle(kind: .lineStart, position: rotatedStart),
            Handle(kind: .lineEnd, position: rotatedEnd)
        ]
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to dragWorld: CGPoint,
        opposite oppWorld: CGPoint?
    ) {
        guard let oppWorld = oppWorld else { return }
        // Calculate new rotation based on dragged and opposite points
        let deltaX = dragWorld.x - oppWorld.x
        let deltaY = dragWorld.y - oppWorld.y
        rotation = atan2(deltaY, deltaX)

        // Reset line to unrotated state using new direction
        let mid = CGPoint(
            x: (dragWorld.x + oppWorld.x) / 2,
            y: (dragWorld.y + oppWorld.y) / 2
        )
        let dragLocal = unrotate(point: dragWorld, around: mid, by: rotation)
        let oppLocal  = unrotate(point: oppWorld, around: mid, by: rotation)

        switch kind {
        case .lineStart: start = dragLocal; end = oppLocal
        case .lineEnd:   start = oppLocal;  end = dragLocal
        default: break
        }
    }

    func makePath(offset: CGPoint = .zero) -> CGPath {

           // 1. build an unrotated line, *including* any offset
           let start = CGPoint(
            x: offset.x + start.x,
            y: offset.y + start.y
           )
           let end = CGPoint(
            x: offset.x + end.x,
            y: offset.y + end.y
           )

           let path = CGMutablePath()
           path.move(to: start)
           path.addLine(to: end)

           // 2. rotate about its midpoint
           let mid = CGPoint(
            x: (start.x + end.x) * 0.5,
            y: (start.y + end.y) * 0.5
           )

           var transform = CGAffineTransform.identity
                  .translatedBy(x: mid.x, y: mid.y)
                  .rotated(by: rotation)
                  .translatedBy(x: -mid.x, y: -mid.y)

           return path.copy(using: &transform) ?? path
       }
}
