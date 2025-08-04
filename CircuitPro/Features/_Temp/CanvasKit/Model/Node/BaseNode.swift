import CoreGraphics
import AppKit

/// A concrete implementation of the `CanvasNode` protocol that provides the fundamental
/// behaviors required for a scene graph, including hierarchy management and transform calculation.
///
/// Concrete node types (like `PrimitiveNode` or `SymbolNode`) should inherit from `BaseNode`
/// to avoid re-implementing this core logic. They can then override methods like `makeBodyParameters()`
/// and `hitTest(_:tolerance:)` to provide their specific visual and interactive behavior.
class BaseNode: CanvasNode {

    // MARK: - Stored Properties
    
    let id: UUID = UUID()
    weak var parent: (any CanvasNode)?
    var children: [any CanvasNode] = []
    
    var isVisible: Bool = true
    var position: CGPoint = .zero
    var rotation: CGFloat = 0.0
    // Note: Scale could be added here later if needed: `var scale: CGFloat = 1.0`

    // MARK: - Hierarchy Management
    
    func addChild(_ node: any CanvasNode) {
        node.removeFromParent()
        node.parent = self
        children.append(node)
    }

    func removeFromParent() {
        parent?.children.removeAll { $0.id == self.id }
        parent = nil
    }

    // MARK: - Transforms
    
    var localTransform: CGAffineTransform {
        return CGAffineTransform(translationX: position.x, y: position.y).rotated(by: rotation)
    }

    var worldTransform: CGAffineTransform {
        if let parent = parent {
            return localTransform.concatenating(parent.worldTransform)
        } else {
            return localTransform
        }
    }
    
    static func == (lhs: BaseNode, rhs: BaseNode) -> Bool {
        return lhs.id == rhs.id
    }

    /// Provides the `Hashable` conformance.
    /// The hash value is based on the node's unique ID, which is consistent with the `==` operator.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Coordinate Space Conversion
    
    // --- THIS IS THE FIX ---
    // Added the '-> CGPoint' return type to match the protocol.
    func convert(_ point: CGPoint, from sourceNode: (any CanvasNode)?) -> CGPoint {
        let sourceTransform = sourceNode?.worldTransform ?? .identity
        let destinationTransform = self.worldTransform
        
        let worldPoint = point.applying(sourceTransform)
        // Correctly inverting the destination transform to map from world to local.
        return worldPoint.applying(destinationTransform.inverted())
    }

    // --- THIS IS THE FIX ---
    // Added the '-> CGPoint' return type to match the protocol.
    func convert(_ point: CGPoint, to destinationNode: (any CanvasNode)?) -> CGPoint {
        let sourceTransform = self.worldTransform
        let destinationTransform = destinationNode?.worldTransform ?? .identity
        
        let worldPoint = point.applying(sourceTransform)
        // Correctly inverting the destination transform to map from world to the other node's local space.
        return worldPoint.applying(destinationTransform.inverted())
    }

    // MARK: - Overridable Drawing & Interaction (Default Implementations)

    /// Default implementation for `Drawable`. Subclasses should override this
    /// to provide their specific drawing parameters.
    func makeBodyParameters() -> [DrawingParameters] {
        return [] // Base node has no appearance.
    }
    
    /// Default implementation for `Drawable`. The base implementation simply creates
    /// a halo from the node's `boundingBox`. Subclasses can provide a more precise path.
    func makeHaloPath() -> CGPath? {
        let box = self.boundingBox
        guard !box.isNull else { return nil }
        return CGPath(rect: box, transform: nil)
    }

    /// Default implementation for `Hittable`. Subclasses should override this
    /// to define their interactive shape. The default implementation only hits children.
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // Only interact with visible nodes.
        guard self.isVisible else { return nil }

        // Iterate children from top to bottom (last child is drawn last/on top).
        for child in children.reversed() {
            // Convert the point from our coordinate space into the child's space.
            let localPoint = self.convert(point, to: child)
            
            if let hit = child.hitTest(localPoint, tolerance: tolerance) {
                // --- THIS IS THE FIX ---
                // Simply return the hit result from the child directly.
                // Do NOT re-wrap it or prepend the parent's ID. The child's
                // hit result already contains the correct ownership path.
                return hit
            }
        }
        return nil // Base implementation doesn't hit itself, only its children.
    }

    /// Default implementation for `Bounded`. Subclasses should override this to
    /// provide a more accurate bounding box.
    var boundingBox: CGRect {
        // The bounding box is the union of all visible children's bounding boxes,
        // each transformed into this node's local coordinate space.
        let childBoxes = children.compactMap { child -> CGRect? in
            guard child.isVisible else { return nil }
            return child.boundingBox.applying(child.localTransform)
        }
        return childBoxes.reduce(CGRect.null) { $0.union($1) }
    }
}
