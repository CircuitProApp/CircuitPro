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
    
    var layerId: UUID?
    
    var maximumCornerRadius: CGFloat {
        return min(size.width, size.height) / 2
    }

    func handles() -> [Handle] {
        let halfW = size.width / 2
        let halfH = size.height / 2

        // Handles are defined in the primitive's local coordinate space,
        // assuming a center at (0,0) and no rotation. The render layer
        // is responsible for applying the node's world transform.
        return [
            Handle(kind: .rectTopLeft,    position: CGPoint(x: -halfW, y:  halfH)),
            Handle(kind: .rectTopRight,   position: CGPoint(x:  halfW, y:  halfH)),
            Handle(kind: .rectBottomRight,position: CGPoint(x:  halfW, y: -halfH)),
            Handle(kind: .rectBottomLeft, position: CGPoint(x: -halfW, y: -halfH))
        ]
    }
    mutating func updateHandle(
        _ kind: Handle.Kind,
        to dragLocal: CGPoint,
        opposite oppLocal: CGPoint?
    ) {
        guard let oppLocal = oppLocal else { return }

        // dragLocal and oppLocal are in the node's local coordinate space.
        // In this space, the rectangle is centered at (0,0) before this update.

        // The new size is the absolute difference between the two local points.
        size = CGSize(
            width: max(abs(dragLocal.x - oppLocal.x), 1),
            height: max(abs(dragLocal.y - oppLocal.y), 1)
        )

        // The new center of the rectangle is the midpoint of the diagonal.
        // This point is also in the node's local coordinate space.
        let newCenterLocal = CGPoint(
            x: (dragLocal.x + oppLocal.x) * 0.5,
            y: (dragLocal.y + oppLocal.y) * 0.5
        )

        // The primitive's `position` is its origin's location in the parent's coordinate space.
        // The `newCenterLocal` represents the offset we need to move our origin by,
        // from the perspective of our local coordinate system.
        // To apply this offset to our `position`, we must first transform
        // the offset vector from our local space to the parent's space.
        // The transform from local to parent space is just the rotation component.
        let positionOffset = newCenterLocal.applying(CGAffineTransform(rotationAngle: rotation))

        // Add the transformed offset to the current position.
        position = CGPoint(
            x: position.x + positionOffset.x,
            y: position.y + positionOffset.y
        )
    }
    func makePath() -> CGPath {
        // Create the rect centered at the origin, not at self.position.
        let frame = CGRect(
            x: -size.width * 0.5,
            y: -size.height * 0.5,
            width: size.width,
            height: size.height
        )

        let path = CGMutablePath()
        let clampedCornerRadius = max(0, min(cornerRadius, min(size.width, size.height) * 0.5))
        path.addRoundedRect(in: frame, cornerWidth: clampedCornerRadius, cornerHeight: clampedCornerRadius)

        return path
    }
}
