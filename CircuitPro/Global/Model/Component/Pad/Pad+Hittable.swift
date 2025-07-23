//
//  Pad+Hittable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

extension Pad: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        for primitive in allPrimitives {
            if primitive.hitTest(point, tolerance: tolerance) != nil {
                return .canvasElement(part: .pad(id: id, position: position))
            }
        }
        return nil
    }
}
