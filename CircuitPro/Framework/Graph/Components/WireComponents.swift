//
//  WireComponents.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import CoreGraphics
import Foundation

struct WireVertexComponent: Hashable {
    var point: CGPoint
    var clusterID: UUID?
    var ownership: VertexOwnership
}

struct WireEdgeComponent: Hashable {
    var start: NodeID
    var end: NodeID
    var clusterID: UUID?
}
