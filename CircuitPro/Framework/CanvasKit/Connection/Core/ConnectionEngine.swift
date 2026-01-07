//
//  ConnectionEngine.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import CoreGraphics
import Foundation

/// A domain-agnostic routing policy for connections on the canvas.
///
/// CanvasKit calls into the engine to convert anchors/edges into drawable routes.
protocol ConnectionEngine {

    /// Builds a route for a specific edge based on anchor positions.
    func route(
        edge: any ConnectionEdge,
        anchorsByID: [UUID: CGPoint],
        context: ConnectionRoutingContext
    ) -> ConnectionRoute

    /// Builds a route between two points (useful for previews or adjacency-based graphs).
    func route(
        from start: CGPoint,
        to end: CGPoint,
        context: ConnectionRoutingContext
    ) -> ConnectionRoute
}
