import Foundation
import CoreGraphics

/// Represents the specific part of a connection that was hit by an interaction.
enum ConnectionHitTarget {
    /// A click occurred in an empty area.
    case emptySpace(point: CGPoint)
    /// A click landed on an existing vertex.
    case vertex(vertexID: UUID, onConnection: UUID, position: CGPoint, type: VertexType)
    /// A click landed on an existing edge.
    case edge(edgeID: UUID, onConnection: UUID, at: CGPoint)
}
