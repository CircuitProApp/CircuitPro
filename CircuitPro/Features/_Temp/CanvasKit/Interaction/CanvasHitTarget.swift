import CoreGraphics
import Foundation

/// A generic, detailed result of a hit-test operation on the canvas.
/// This structure identifies which node was hit, where, and an optional
/// application-defined identifier for a specific part of that node.
struct CanvasHitTarget: Hashable {

    /// The `CanvasNode` that was successfully hit.
    /// This provides direct access to the hit element, its properties, and its position in the scene hierarchy.
    let node: any CanvasNode

    /// An optional, application-defined value that identifies a specific sub-component within the `node`.
    /// For example, a complex symbol node might return a string like `"pin_1"`, while a simple
    /// primitive node might return `nil` or a generic identifier like `"body"`.
    let partIdentifier: AnyHashable?

    /// The precise location of the hit in world coordinates.
    let position: CGPoint
    
    // The protocol conformance for `Hashable` can be implemented like this:
    static func == (lhs: CanvasHitTarget, rhs: CanvasHitTarget) -> Bool {
        return lhs.node.id == rhs.node.id &&
               lhs.partIdentifier == rhs.partIdentifier &&
               lhs.position == rhs.position
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(node.id)
        hasher.combine(partIdentifier)
        hasher.combine(position.x)
        hasher.combine(position.y)
    }
}
