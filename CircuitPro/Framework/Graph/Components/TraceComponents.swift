//
//  TraceComponents.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

struct TraceVertexComponent: GraphComponent {
    var point: CGPoint
}

struct TraceEdgeComponent: GraphComponent {
    var start: NodeID
    var end: NodeID
    var width: CGFloat
    var layerId: UUID?
}
