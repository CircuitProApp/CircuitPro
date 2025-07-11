//
//  LinePrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct LinePrimitive: GraphicPrimitive {

    let id: UUID
    var start: CGPoint
    var end: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool = false
    var color: SDColor

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
        let rotatedStart = start.rotated(around: mid, by: rotation)
        let rotatedEnd = end.rotated(around: mid, by: rotation)
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
        let dragLocal = dragWorld.rotated(around: mid, by: -rotation)
        let oppLocal  = oppWorld.rotated(around: mid, by: -rotation)

        switch kind {
        case .lineStart: start = dragLocal; end = oppLocal
        case .lineEnd:   start = oppLocal;  end = dragLocal
        default: break
        }
    }

    func makePath() -> CGPath {

        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        var transform = CGAffineTransform
            .identity
            .translatedBy(x: position.x, y: position.y)
            .rotated(by: rotation)
            .translatedBy(x: -position.x, y: -position.y)

        return path.copy(using: &transform) ?? path
    }
}
