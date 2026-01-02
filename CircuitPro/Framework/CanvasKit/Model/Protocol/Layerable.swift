//
//  Layerable.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// Defines an object that belongs to a single, specific `CanvasLayer`.
/// This is suitable for elements that live entirely on one layer.
protocol Layerable {
    /// The unique identifier of the `CanvasLayer` this object is associated with.
    var layerId: UUID? { get set }
}
