//
//  Pin+Hittable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit
import CoreGraphics

extension Pin: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        // 1. Get the unified outline path from the new helper method in the Drawable extension.
        // This ensures the hittable area is identical to the halo shape, without
        // creating a dependency on the selection state.
        guard let unifiedOutline = makePinOutline() else { return nil }

        // 2. Create an expanded, fillable shape for robust hit-testing.
        let hittableArea = unifiedOutline.copy(
            strokingWithWidth: tolerance * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )

        // 3. Perform the hit test. If the point isn't in the area, it's a miss.
        guard hittableArea.contains(point) else { return nil }
        
        // 4. If a hit occurred, create the standard CanvasHitTarget.
        return CanvasHitTarget(
            partID: self.id,
            ownerPath: [self.id],
            kind: .pin,
            position: point
        )
    }
}
