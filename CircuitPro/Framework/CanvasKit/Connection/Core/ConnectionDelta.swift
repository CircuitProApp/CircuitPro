//
//  ConnectionDelta.swift
//  CircuitPro
//
//  Created by Codex on 1/4/26.
//

import Foundation

struct ConnectionDelta {
    var removedAnchorIDs: Set<UUID> = []
    var updatedAnchors: [any CanvasItem & ConnectionAnchor] = []
    var addedAnchors: [any CanvasItem & ConnectionAnchor] = []
    var removedEdgeIDs: Set<UUID> = []
    var updatedEdges: [any CanvasItem & ConnectionEdge] = []
    var addedEdges: [any CanvasItem & ConnectionEdge] = []

    var isEmpty: Bool {
        removedAnchorIDs.isEmpty
            && updatedAnchors.isEmpty
            && addedAnchors.isEmpty
            && removedEdgeIDs.isEmpty
            && updatedEdges.isEmpty
            && addedEdges.isEmpty
    }
}
