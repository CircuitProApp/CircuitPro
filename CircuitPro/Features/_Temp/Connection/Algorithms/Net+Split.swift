//
//  Net+Split.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import Foundation
import CoreGraphics

extension Net {
    @discardableResult
    mutating func splitEdge(withID edgeID: UUID, at point: CGPoint) -> UUID? {
        // 1. Find edge
        guard let edgeIndex = edges.firstIndex(where: { $0.id == edgeID }),
              let nodeA = nodeByID[edges[edgeIndex].startNodeID],
              let nodeB = nodeByID[edges[edgeIndex].endNodeID] else {
            return nil
        }

        // 2. Create new junction node
        let junction = Node(id: UUID(), point: point, kind: .junction)
        nodeByID[junction.id] = junction

        // 3. Create two new edges
        let edge1 = Edge(id: UUID(), startNodeID: nodeA.id, endNodeID: junction.id)
        let edge2 = Edge(id: UUID(), startNodeID: junction.id, endNodeID: nodeB.id)

        // 4. Replace original edge with new edges
        edges.remove(at: edgeIndex)
        edges.append(contentsOf: [edge1, edge2])

        return junction.id
    }

    mutating func splitEdge(
        withID edgeID: UUID,
        at point: CGPoint,
        reusing nodeID: UUID
    ) -> UUID? {
        guard let newID = splitEdge(withID: edgeID, at: point) else { return nil }
        replaceNodeID(newID, with: nodeID)
        return nodeID
    }
}
