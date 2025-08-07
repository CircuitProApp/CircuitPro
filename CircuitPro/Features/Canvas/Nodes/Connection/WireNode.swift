//
//  WireNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit

/// A scene graph node that represents a single, straight wire segment (an edge)
/// from the schematic graph.
final class WireNode: BaseNode {

    // Store the ID of the edge and a reference to the graph, not the edge struct itself.
    let edgeID: ConnectionEdge.ID
    let graph: SchematicGraph

    override var isSelectable: Bool { true }

    init(edgeID: ConnectionEdge.ID, graph: SchematicGraph) {
        self.edgeID = edgeID
        self.graph = graph
        // The node's ID is the same as the edge's ID for easy mapping and selection.
        super.init(id: edgeID)
    }

    /// Creates the drawing parameters for the wire's body.
    override func makeBodyParameters() -> [DrawingParameters] {
        guard let edge = graph.edges[edgeID],
              let startVertex = graph.vertices[edge.start],
              let endVertex = graph.vertices[edge.end] else {
            return []
        }

        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)

        // Customize appearance as needed (e.g., based on net color).
        return [
            DrawingParameters(path: path,
                              lineWidth: 1.0, strokeColor: NSColor.controlAccentColor.cgColor,
                              lineCap: .round)
        ]
    }
    
    /// Creates the drawing parameters for the wire's selection halo.
    override func makeHaloPath() -> CGPath? {
        guard let edge = graph.edges[edgeID],
              let startVertex = graph.vertices[edge.start],
              let endVertex = graph.vertices[edge.end] else {
            return nil
        }
        
        let path = CGMutablePath()
        path.move(to: startVertex.point)
        path.addLine(to: endVertex.point)
        
        // The halo is a thicker, stroked version of the path.
        // The .copy(strokingWithWidth:) method is perfect for this.
        return path.copy(strokingWithWidth: 8.0, lineCap: .round, lineJoin: .round, miterLimit: 0)
    }

    /// Performs hit-testing specifically for this line segment.
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // A WireNode has no children, so we can go straight to its own hit-test logic.
        guard let edge = graph.edges[edgeID],
              let startV = graph.vertices[edge.start],
              let endV = graph.vertices[edge.end],
              isPoint(point, onSegmentBetween: startV.point, p2: endV.point, tolerance: tolerance) else {
            return nil
        }
        
        // If the point is on the line, this node is the hit target.
        // We use the correct initializer for CanvasHitTarget. For a simple wire,
        // there's no specific "part," so we can pass nil.
        return CanvasHitTarget(node: self, partIdentifier: nil, position: point)
    }
    
    /// Helper function to check if a point lies on this line segment within a given tolerance.
    private func isPoint(_ p: CGPoint, onSegmentBetween p1: CGPoint, p2: CGPoint, tolerance: CGFloat) -> Bool {
        let minX = min(p1.x, p2.x) - tolerance, maxX = max(p1.x, p2.x) + tolerance
        let minY = min(p1.y, p2.y) - tolerance, maxY = max(p1.y, p2.y) + tolerance

        // First, do a fast check to see if the point is within the bounding box of the segment.
        guard p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY else { return false }

        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        // Handle perfectly vertical and horizontal lines.
        let epsilon: CGFloat = 1e-6
        if abs(dx) < epsilon { return abs(p.x - p1.x) < tolerance }
        if abs(dy) < epsilon { return abs(p.y - p1.y) < tolerance }

        // Calculate the perpendicular distance from the point to the infinite line.
        let distance = abs(dy * p.x - dx * p.y + p2.y * p1.x - p2.x * p1.y) / hypot(dx, dy)
        
        return distance < tolerance
    }
}
