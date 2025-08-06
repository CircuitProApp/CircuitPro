//import AppKit
//
///// Performs detailed hit-testing for all interactive items on the workbench.
//struct SchematicGraphHitTestService {
//
//    // The old hitTest function that looped over nodes has been REMOVED.
//
//    /// Encapsulates hit-testing on the schematic graph.
//    static func hitTest(
//        at point: CGPoint,
//        graph: SchematicGraph,
//        tolerance: CGFloat
//    ) -> CanvasHitTarget? {
//        // Prioritize hitting vertices over edges, as they are smaller targets.
//        for vertex in graph.vertices.values {
//            let distance = hypot(point.x - vertex.point.x, point.y - vertex.point.y)
//            if distance < tolerance {
//                let connectionCount = graph.adjacency[vertex.id]?.count ?? 0
//                let type: VertexType
//                switch connectionCount {
//                case 0, 1: type = .endpoint
//                case 2: type = .corner
//                default: type = .junction
//                }
//                
//                return CanvasHitTarget(
//                    partID: vertex.id,
//                    ownerPath: [], // Vertices aren't directly selectable entities
//                    kind: .vertex(type: type),
//                    position: vertex.point
//                )
//            }
//        }
//
//        // Check edges if no vertex was hit.
//        for edge in graph.edges.values {
//            guard let startVertex = graph.vertices[edge.start],
//                  let endVertex = graph.vertices[edge.end] else { continue }
//
//            if isPointOnLineSegment(point: point, start: startVertex.point, end: endVertex.point, tolerance: tolerance) {
//                let orientation: LineOrientation = (startVertex.point.x == endVertex.point.x) ? .vertical : .horizontal
//                
//                return CanvasHitTarget(
//                    partID: edge.id,
//                    ownerPath: [edge.id], // Edges are their own selectable owner
//                    kind: .edge(orientation: orientation),
//                    position: point
//                )
//            }
//        }
//
//        return nil
//    }
//}
//
///// Utility function to check if a point is close to a line segment.
///// This is a top-level private function, which is fine, or it could be made a private static helper.
//private func isPointOnLineSegment(
//    point: CGPoint,
//    start startPoint: CGPoint,
//    end endPoint: CGPoint,
//    tolerance: CGFloat
//) -> Bool {
//    let boundingBox = CGRect(origin: startPoint, size: .zero)
//        .union(.init(origin: endPoint, size: .zero))
//        .insetBy(dx: -tolerance, dy: -tolerance)
//    guard boundingBox.contains(point) else { return false }
//
//    let deltaX = endPoint.x - startPoint.x
//    let deltaY = endPoint.y - startPoint.y
//
//    if deltaX == 0 && deltaY == 0 {
//        return hypot(point.x - startPoint.x, point.y - startPoint.y) < tolerance
//    }
//
//    let projectionFactor = ((point.x - startPoint.x) * deltaX + (point.y - startPoint.y) * deltaY) / (deltaX * deltaX + deltaY * deltaY)
//
//    let closestPoint: CGPoint
//    if projectionFactor < 0 {
//        closestPoint = startPoint
//    } else if projectionFactor > 1 {
//        closestPoint = endPoint
//    } else {
//        closestPoint = CGPoint(
//            x: startPoint.x + projectionFactor * deltaX,
//            y: startPoint.y + projectionFactor * deltaY
//        )
//    }
//
//    return hypot(point.x - closestPoint.x, point.y - closestPoint.y) < tolerance
//}
