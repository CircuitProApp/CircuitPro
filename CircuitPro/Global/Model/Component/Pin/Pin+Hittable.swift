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
        // --- The geometric hit-testing logic is excellent and remains unchanged ---
        // 1. Get the unified outline path representing the pin's full visual footprint.
        guard let haloParams = makeHaloParameters() else { return nil }
        let unifiedOutline = haloParams.path

        // 2. Create an expanded, fillable shape for robust hit-testing.
        let hittableArea = unifiedOutline.copy(
            strokingWithWidth: tolerance * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )

        // 3. Perform the hit test. If the point isn't in the area, it's a miss.
        guard hittableArea.contains(point) else { return nil }
        
        // --- This part is updated to return our new, unified struct ---
        // 4. If a hit occurred, create the standard CanvasHitTarget.
        return CanvasHitTarget(
            // The specific part that was hit is this Pin instance.
            partID: self.id,
            
            // For a standalone Pin, its ownership path contains only its own ID.
            // If this Pin is part of a Symbol, the Symbol's hitTest implementation
            // will be responsible for prepending its own ID to this path when it
            // receives this hit record. This cleanly replaces the old `parentSymbolID`.
            ownerPath: [self.id],
            
            // The kind is specifically a Pin.
            kind: .pin,
            
            // Pass along the precise location of the hit.
            position: point
        )
    }
}
