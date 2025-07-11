//
//  CirclePrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct CirclePrimitive: GraphicPrimitive {

    let id: UUID
    var radius: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var color: SDColor
    var filled: Bool

    func handles() -> [Handle] {
        let rawPoint = CGPoint(x: position.x + radius, y: position.y)
        let rotated = rawPoint.rotated(around: position, by: rotation)
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

    func makePath() -> CGPath {
            let path = CGMutablePath()
            path.addArc(
                center: position,
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: false
            )

            var transform = CGAffineTransform.identity
                .translatedBy(x: position.x, y: position.y)
                .rotated(by: rotation)
                .translatedBy(x: -position.x, y: -position.y)
            return path.copy(using: &transform) ?? path
        }
}
