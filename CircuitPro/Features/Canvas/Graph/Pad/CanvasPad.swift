//
//  CanvasPad.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics
import Foundation

struct CanvasPad {
    var pad: Pad
    var ownerID: UUID?
    var ownerPosition: CGPoint
    var ownerRotation: CGFloat
    var layerId: UUID?
    var isSelectable: Bool

    var id: UUID {
        GraphPadID.makeID(ownerID: ownerID, padID: pad.id)
    }
}

extension CanvasPad: Equatable {}

extension CanvasPad: CanvasItem {
    var elementID: GraphElementID { .node(NodeID(GraphPadID.makeID(ownerID: ownerID, padID: pad.id))) }

    func apply(to graph: CanvasGraph) {
        let nodeID = NodeID(GraphPadID.makeID(ownerID: ownerID, padID: pad.id))
        if !graph.nodes.contains(nodeID) {
            graph.addNode(nodeID)
        }
        if let existing = graph.component(CanvasPad.self, for: nodeID), existing == self {
            return
        }
        graph.setComponent(self, for: nodeID)
    }
}

extension CanvasPad: ConnectionPoint {
    var position: CGPoint {
        CGPoint.zero.applying(worldTransform)
    }
}

extension CanvasPad: ConnectionPointProvider {
    var connectionPoints: [any ConnectionPoint] { [self] }
}

extension CanvasPad {
    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
            .rotated(by: ownerRotation)
    }

    var worldTransform: CGAffineTransform {
        CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
            .rotated(by: pad.rotation)
            .concatenating(ownerTransform)
    }
}
