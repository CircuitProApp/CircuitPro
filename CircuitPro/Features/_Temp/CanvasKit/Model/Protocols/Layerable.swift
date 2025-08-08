//
//  Layerable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/8/25.
//

import Foundation

/// Defines an object that belongs to a single, specific `CanvasLayer`.
/// This is suitable for elements like graphic primitives (lines, text, shapes)
/// that exist entirely on one layer, such as a silkscreen or courtyard.
protocol Layerable {
    /// The unique identifier of the `CanvasLayer` this object is associated with.
    var layerId: UUID? { get set }
}
