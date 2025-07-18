//
//  WorkbenchHitTestService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import AppKit

/// Performs detailed hit-testing for all interactive items on the workbench.
struct WorkbenchHitTestService {

    /// Finds the most specific interactive element at a given point on the canvas.
    ///
    /// This method checks elements in reverse rendering order (top-most first) to ensure
    /// the correct element is picked. It checks connections first, then standard canvas elements.
    ///
    /// - Parameters:
    ///   - point: The point to test, in world coordinates.
    ///   - elements: The array of all `CanvasElement` items on the workbench.
    ///   - schematicGraph: The `SchematicGraph` containing all connection elements.
    ///   - magnification: The current zoom level of the canvas, used to adjust hit tolerance.
    /// - Returns: A `CanvasHitTarget` describing the hit, or `nil` if nothing was hit.
    func hitTest(
        at point: CGPoint,
        elements: [CanvasElement],
        schematicGraph: SchematicGraph,
        magnification: CGFloat
    ) -> CanvasHitTarget? {
        let tolerance = 5.0 / magnification

        // 1. Hit-test the schematic graph first, as connections might be "on top" of elements.
        // Prioritize hitting vertices over edges.
        for vertex in schematicGraph.vertices.values {
            let distance = hypot(point.x - vertex.point.x, point.y - vertex.point.y)
            if distance < tolerance {
                // TODO: Determine the actual VertexType (endpoint, corner, junction)
                let type = VertexType.corner
                return .connection(part: .vertex(id: vertex.id, position: vertex.point, type: type))
            }
        }

        for edge in schematicGraph.edges.values {
            guard let startVertex = schematicGraph.vertices[edge.start],
                  let endVertex = schematicGraph.vertices[edge.end] else { continue }
            
            let p1 = startVertex.point
            let p2 = endVertex.point
            
            let boundingBox = CGRect(origin: p1, size: .zero).union(.init(origin: p2, size: .zero)).insetBy(dx: -tolerance, dy: -tolerance)
            guard boundingBox.contains(point) else { continue }

            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            
            if dx == 0 && dy == 0 { continue }
            
            let t = ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / (dx * dx + dy * dy)
            
            let closestPoint: CGPoint
            if t < 0 {
                closestPoint = p1
            } else if t > 1 {
                closestPoint = p2
            } else {
                closestPoint = CGPoint(x: p1.x + t * dx, y: p1.y + t * dy)
            }
            
            let distance = hypot(point.x - closestPoint.x, point.y - closestPoint.y)
            
            if distance < tolerance {
                let orientation: LineOrientation = (p1.x == p2.x) ? .vertical : .horizontal
                return .connection(part: .edge(id: edge.id, at: point, orientation: orientation))
            }
        }

        // 2. If no connection was hit, check the canvas elements.
        for element in elements.reversed() {
            if let hit = element.hitTest(point, tolerance: tolerance) {
                return hit
            }
        }

        // 3. If nothing was hit, return nil.
        return nil
    }
}
