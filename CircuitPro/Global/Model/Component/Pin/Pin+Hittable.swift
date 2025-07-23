//
//  Pin+Hittable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

extension Pin: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        // 1. Get the unified outline path from our halo generation logic.
        // Reusing `makeHaloParameters` is ideal because it already creates a
        // single CGPath that represents the entire pin's visual footprint,
        // including primitives and all text glyphs.
        guard let haloParams = makeHaloParameters() else { return nil }
        let unifiedOutline = haloParams.path

        // 2. Create a "fat" version of the path for hit testing.
        // We stroke the unified outline with a width of `tolerance * 2`.
        // This creates a new, fillable shape that extends `tolerance` points
        // on either side of the original path, making it easy to check if the
        // tap location is "near" any part of the pin.
        let hittableArea = unifiedOutline.copy(
            strokingWithWidth: tolerance * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )

        // 3. Perform the hit test.
        // If the point is contained within this new, fatter shape, it's a hit.
        if hittableArea.contains(point) {
            // A `parentSymbolID` would be provided if this pin were part of a larger component.
            return .canvasElement(part: .pin(id: id, parentSymbolID: nil, position: position))
        }

        // 4. If the point is not inside the hittable area, it's a miss.
        return nil
    }
}
