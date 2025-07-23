//
//  Pin+Hittable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

extension Pin: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        // 1. get the outline that selection/halo already uses
        guard let shape = selectionPath() else { return nil }

        // 2. inflate it by the tolerance and ask Core Graphics
        let fat = shape.copy(
            strokingWithWidth: tolerance * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )

        if fat.contains(point) {
            return .canvasElement(part: .pin(id: id, parentSymbolID: nil, position: position))
        }
        return nil
    }
}
