//
//  CanvasCircle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct CanvasCircle: CanvasPrimitive {

    let id: UUID
    var radius: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var color: SDColor?
    var filled: Bool

    var layerId: UUID?

    func handles() -> [CanvasHandle] {
        // The handle is defined in local space, assuming a center at (0,0)
        // and no rotation. The render layer will apply the world transform.
        return [CanvasHandle(kind: .circleRadius, position: CGPoint(x: radius, y: 0))]
    }

    mutating func updateHandle(
        _ kind: CanvasHandle.Kind,
        to newPos: CGPoint
    ) {
        guard kind == .circleRadius else { return }

        // `newPos` is the mouse position in the circle's local coordinate space,
        // which has been rotated by `self.rotation`. To break the feedback loop,
        // we need to counteract this. We can rotate `newPos` forward by the current
        // rotation to get the drag vector in the parent's coordinate space.
        let dragVectorInParentSpace = newPos.applying(CGAffineTransform(rotationAngle: self.rotation))

        // The new radius is the length of this stable vector.
        radius = max(hypot(dragVectorInParentSpace.x, dragVectorInParentSpace.y), 1)

        // The new rotation is the angle of this stable vector.
        rotation = atan2(dragVectorInParentSpace.y, dragVectorInParentSpace.x)
    }

    mutating func updateHandle(
        _ kind: CanvasHandle.Kind,
        to newPos: CGPoint,
        opposite _: CGPoint?
    ) {
        // Forward to the corrected implementation.
        updateHandle(kind, to: newPos)
    }
    func makePath() -> CGPath {
        let path = CGMutablePath()

        // THE FIX: The center is now CGPoint.zero, not self.position.
        path.addArc(
            center: .zero,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )

        return path
    }
}
