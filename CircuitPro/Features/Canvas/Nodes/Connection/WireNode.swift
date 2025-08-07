//
//  WireNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit
import Observation

@Observable
final class WireNode: BaseNode {
    let edgeID: ConnectionEdge.ID
    let graph: SchematicGraph

    override var isSelectable: Bool { true }

    // --- NEW: Add a computed property for the wire's orientation ---
    var orientation: LineOrientation {
        guard let edge = graph.edges[edgeID],
              let startV = graph.vertices[edge.start],
              let endV = graph.vertices[edge.end] else {
            return .horizontal // Default for safety
        }
        
        // A perfectly vertical line has a negligible difference in x-coordinates.
        return abs(startV.point.x - endV.point.x) < 1e-6 ? .vertical : .horizontal
    }

    init(edgeID: ConnectionEdge.ID, graph: SchematicGraph) {
        self.edgeID = edgeID
        self.graph = graph
        super.init(id: edgeID)
    }

    // --- MODIFIED: Update hitTest to return enriched information ---
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        guard let edge = graph.edges[edgeID],
              let startV = graph.vertices[edge.start],
              let endV = graph.vertices[edge.end],
              isPoint(point, onSegmentBetween: startV.point, p2: endV.point, tolerance: tolerance) else {
            return nil
        }
        
        // When hit, package its orientation into the partIdentifier.
        return CanvasHitTarget(node: self, partIdentifier: self.orientation, position: point)
    }
    
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
        return path.copy(strokingWithWidth: 1.0, lineCap: .round, lineJoin: .round, miterLimit: 0)
    }
    
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
