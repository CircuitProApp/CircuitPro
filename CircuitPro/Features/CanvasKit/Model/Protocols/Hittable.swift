//
//  Hittable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.06.25.
//

import SwiftUI

protocol Hittable {
    /// Determines if a point intersects with the object.
    /// - Parameters:
    ///   - point: The point to test, in the element's coordinate space.
    ///   - tolerance: The distance from the object's geometry within which the point is considered a "hit".
    /// - Returns: A `CanvasHitTarget` if the point hits the object, otherwise `nil`.
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget?
}
