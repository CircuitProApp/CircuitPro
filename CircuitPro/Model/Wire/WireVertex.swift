//
//  WireVertex.swift
//  CircuitPro
//
//  Created by Codex on 1/2/26.
//

import CoreGraphics
import Foundation

/// A lightweight wire point that can participate in CanvasKit interactions.
struct WireVertex: CanvasItem, ConnectionPoint, Hashable, Codable {
    let id: UUID
    var position: CGPoint

    init(id: UUID = UUID(), position: CGPoint) {
        self.id = id
        self.position = position
    }
}
