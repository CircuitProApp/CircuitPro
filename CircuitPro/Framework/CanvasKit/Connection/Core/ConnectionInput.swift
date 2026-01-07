import Foundation

enum ConnectionInput {
    case edges(anchors: [any ConnectionAnchor], edges: [any ConnectionEdge])
    case adjacency(anchors: [any ConnectionAnchor], points: [any ConnectionPoint])
}
