//
//  Net+Merge.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import Foundation
import CoreGraphics

extension Net {

    mutating func mergeColinearEdges() {
        func rebuildAdjacency() -> [UUID: [Edge]] {
            var adjacencyMap: [UUID: [Edge]] = [:]
            for edge in edges {
                adjacencyMap[edge.startNodeID, default: []].append(edge)
                adjacencyMap[edge.endNodeID, default: []].append(edge)
            }
            return adjacencyMap
        }

        var adjacency = rebuildAdjacency()
        var didChange = true

        while didChange {
            didChange = false
            for (nodeID, connectedEdges) in adjacency {
                guard connectedEdges.count == 2,
                      let node = nodeByID[nodeID],
                      node.kind != .junction else { continue }

                let edge1 = connectedEdges[0]
                let edge2 = connectedEdges[1]

                let otherNode1 = (edge1.startNodeID == nodeID ? edge1.endNodeID : edge1.startNodeID)
                let otherNode2 = (edge2.startNodeID == nodeID ? edge2.endNodeID : edge2.startNodeID)

                guard otherNode1 != otherNode2,
                      let point0 = nodeByID[otherNode1]?.point,
                      let point2 = nodeByID[otherNode2]?.point else { continue }

                let point1 = node.point

                let isHorizontal = (point0.y == point1.y) && (point1.y == point2.y)
                let isVertical = (point0.x == point1.x) && (point1.x == point2.x)

                guard isHorizontal || isVertical else { continue }

                edges.removeAll { $0.id == edge1.id || $0.id == edge2.id }
                nodeByID.removeValue(forKey: nodeID)

                let newEdge = Edge(id: UUID(), startNodeID: otherNode1, endNodeID: otherNode2)
                edges.append(newEdge)

                adjacency = rebuildAdjacency()
                didChange = true
                break
            }
        }
    }

    static func findAndMergeIntentionalIntersections(
        between netA: inout Net, and netB: inout Net
    ) -> Bool {
        var intersectionHits: [(UUID, UUID, CGPoint)] = []

        for edgeA in netA.edges {
            guard let nodeAStart = netA.nodeByID[edgeA.startNodeID],
                  let nodeAEnd = netA.nodeByID[edgeA.endNodeID] else { continue }

            let segmentA = LineSegment(start: nodeAStart.point, end: nodeAEnd.point)

            for edgeB in netB.edges {
                guard let nodeBStart = netB.nodeByID[edgeB.startNodeID],
                      let nodeBEnd = netB.nodeByID[edgeB.endNodeID] else { continue }

                let segmentB = LineSegment(start: nodeBStart.point, end: nodeBEnd.point)

                if let intersection = segmentA.intersectionPoint(with: segmentB),
                   netA.hasNode(at: intersection) || netB.hasNode(at: intersection) {
                    intersectionHits.append((edgeA.id, edgeB.id, intersection))
                }
            }
        }

        guard !intersectionHits.isEmpty else { return false }

        for hit in intersectionHits {
            let newJunctionID = netA.splitEdge(withID: hit.0, at: hit.2)
            if let junctionID = newJunctionID,
               let index = netB.edges.firstIndex(where: { $0.id == hit.1 }),
               let bStart = netB.nodeByID[netB.edges[index].startNodeID],
               let bEnd = netB.nodeByID[netB.edges[index].endNodeID] {

                let edge1 = Edge(id: UUID(), startNodeID: bStart.id, endNodeID: junctionID)
                let edge2 = Edge(id: UUID(), startNodeID: junctionID, endNodeID: bEnd.id)

                netB.edges.remove(at: index)
                netB.edges.append(contentsOf: [edge1, edge2])
            }
        }

        return true
    }

    static func findAndMergeIntersections(
        between netA: inout Net, and netB: inout Net
    ) -> Bool {
        findAndMergeIntentionalIntersections(between: &netA, and: &netB)
    }

    private func hasNode(at point: CGPoint, tolerance: CGFloat = 0.5) -> Bool {
        nodeByID.values.contains {
            abs($0.point.x - point.x) < tolerance &&
            abs($0.point.y - point.y) < tolerance
        }
    }
}
