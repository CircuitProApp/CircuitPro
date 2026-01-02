//
//  MultiLayerable.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// Defines an object that belongs to multiple `CanvasLayer`s.
/// Useful for elements like vias that appear on more than one layer.
protocol MultiLayerable {
    /// The identifiers of all `CanvasLayer`s this object is associated with.
    var layerIds: [UUID] { get set }
}
