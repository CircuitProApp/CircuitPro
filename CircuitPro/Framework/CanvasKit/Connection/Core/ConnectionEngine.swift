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
    func routes(
        from input: ConnectionInput,
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute]

    func normalize(
        _ input: ConnectionInput,
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta
}

extension ConnectionEngine {
    func normalize(
        _ input: ConnectionInput,
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta {
        ConnectionDelta()
    }
}
