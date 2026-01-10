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
/// CanvasKit calls into the engine to convert points/links into drawable routes.
protocol ConnectionEngine {
    func routes(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute]

    func normalize(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta
}

extension ConnectionEngine {
    func normalize(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta {
        ConnectionDelta()
    }
}
