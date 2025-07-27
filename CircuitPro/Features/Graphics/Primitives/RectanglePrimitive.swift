//
//  RectanglePrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct RectanglePrimitive: GraphicPrimitive {

    let id: UUID
    var size: CGSize
    var cornerRadius: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var filled: Bool
    var color: SDColor

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
                position: topLeft.rotated(around: position, by: rotation)
            ),
            Handle(
                kind: .rectTopRight,
                position: topRight.rotated(around: position, by: rotation)
            ),
            Handle(
                kind: .rectBottomRight,
                position: bottomRight.rotated(around: position, by: rotation)
            ),
            Handle(
                kind: .rectBottomLeft,
                position: bottomLeft.rotated(around: position, by: rotation)
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
    func makePath() -> CGPath {
        let frame = CGRect(
            x: position.x - size.width * 0.5,
            y: position.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )

        let path = CGMutablePath()

        // Use the corner radius (clamped to not exceed half the smallest dimension)
        let clampedCornerRadius = max(0, min(cornerRadius, min(size.width, size.height) * 0.5))
        path.addRoundedRect(in: frame, cornerWidth: clampedCornerRadius, cornerHeight: clampedCornerRadius)

        // Apply rotation about the rectangle's center
        var transform = CGAffineTransform.identity
            .translatedBy(x: position.x, y: position.y)
            .rotated(by: rotation)
            .translatedBy(x: -position.x, y: -position.y)

        return path.copy(using: &transform) ?? path
    }
}
