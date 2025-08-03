//
//  Pad+Hittable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

extension Pad: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // 1. First, we determine if the point hits *any* of the geometric primitives
        //    that make up this Pad. We do this by calling the `hitTest` function
        //    we just defined on each primitive. We only need to know *if* a hit
        //    occurred, not the specific details of which primitive was hit.
        let wasHit = allPrimitives.contains { primitive in
            primitive.hitTest(point, tolerance: tolerance) != nil
        }

        // 2. If none of the Pad's primitives were hit, then the Pad itself was missed.
        guard wasHit else { return nil }

        // 3. If a primitive *was* hit, we now construct a CanvasHitTarget that represents
        //    the Pad itself as the intended target. This is because from the user's point
        //    of view, they clicked on the Pad, not on an individual shape within it.
        return CanvasHitTarget(
            // The partID is the ID of the Pad, because it's the selectable entity.
            partID: self.id,
            
            // For a primary, non-nested element like a Pad, its ownership path
            // simply contains its own ID.
            ownerPath: [self.id],
            
            // The kind of object is explicitly a Pad.
            kind: .pad,
            
            // We pass along the precise location of the hit.
            position: point
        )
    }
}
