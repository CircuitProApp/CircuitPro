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

        // 1. Hit-test the schematic graph (vertices and edges).
        if let graphHit = hitTestSchematicGraph(at: point, graph: schematicGraph, tolerance: tolerance) {
            return graphHit
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

    /// Helper function to encapsulate hit-testing on the schematic graph.
    private func hitTestSchematicGraph(
        at point: CGPoint,
        graph: SchematicGraph,
        tolerance: CGFloat
    ) -> CanvasHitTarget? {
        // Prioritize hitting vertices over edges, as they are smaller targets.
        for vertex in graph.vertices.values {
            let distance = hypot(point.x - vertex.point.x, point.y - vertex.point.y)
            if distance < tolerance {
                let connectionCount = graph.adjacency[vertex.id]?.count ?? 0
                let type: VertexType
                switch connectionCount {
                case 0, 1: type = .endpoint
                case 2: type = .corner
                default: type = .junction
                }

                // A vertex was hit. Vertices are interactive but not selectable entities themselves.
                // We create a CanvasHitTarget with an empty ownerPath.
                return CanvasHitTarget(
                    partID: vertex.id,
                    ownerPath: [], // Empty path signifies no selectable owner.
                    kind: .vertex(type: type),
                    position: vertex.point
                )
            }
        }

        // Check edges if no vertex was hit.
        for edge in graph.edges.values {
            guard let startVertex = graph.vertices[edge.start],
                  let endVertex = graph.vertices[edge.end] else { continue }

            // Using a simple distance calculation for the edge hit test.
            if isPointOnLineSegment(
                point: point,
                start: startVertex.point,
                end: endVertex.point,
                tolerance: tolerance
            ) {
                let orientation: LineOrientation = (startVertex.point.x == endVertex.point.x) ? .vertical : .horizontal

                // An edge was hit. Edges ARE selectable.
                // The ownerPath contains the edge's own ID.
                return CanvasHitTarget(
                    partID: edge.id,
                    ownerPath: [edge.id], // The edge is its own selectable owner.
                    kind: .edge(orientation: orientation),
                    position: point
                )
            }
        }

        return nil
    }
}

/// Utility function to check if a point is close to a line segment.
private func isPointOnLineSegment(
    point: CGPoint,
    start startPoint: CGPoint,
    end endPoint: CGPoint,
    tolerance: CGFloat
) -> Bool {
    let boundingBox = CGRect(origin: startPoint, size: .zero)
        .union(.init(origin: endPoint, size: .zero))
        .insetBy(dx: -tolerance, dy: -tolerance)
    guard boundingBox.contains(point) else { return false }

    let deltaX = endPoint.x - startPoint.x
    let deltaY = endPoint.y - startPoint.y

    if deltaX == 0 && deltaY == 0 {
        return hypot(point.x - startPoint.x, point.y - startPoint.y) < tolerance
    }

    let projectionFactor = ((point.x - startPoint.x) * deltaX + (point.y - startPoint.y) * deltaY) / (deltaX * deltaX + deltaY * deltaY) // swiftlint:disable:this line_length

    let closestPoint: CGPoint
    if projectionFactor < 0 {
        closestPoint = startPoint
    } else if projectionFactor > 1 {
        closestPoint = endPoint
    } else {
        closestPoint = CGPoint(
            x: startPoint.x + projectionFactor * deltaX,
            y: startPoint.y + projectionFactor * deltaY
        )
    }

    return hypot(point.x - closestPoint.x, point.y - closestPoint.y) < tolerance
}
