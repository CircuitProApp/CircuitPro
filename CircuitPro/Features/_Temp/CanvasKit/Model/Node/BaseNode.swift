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
    
    let id: UUID
    weak var parent: (any CanvasNode)?
    var children: [any CanvasNode] = []
    
    var isVisible: Bool = true
    
    var isSelectable: Bool {
        return true
    }
    
    var position: CGPoint {
        get { .zero }
        set { /* do nothing */ }
    }
    var rotation: CGFloat {
        get { 0.0 }
        set { /* do nothing */ }
    }
    
    init(id: UUID = UUID()) {
        self.id = id
    }

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
        guard self.isVisible else { return nil }

        for child in children.reversed() {
            // We transform the incoming point into the child's coordinate system.
            let localPoint = point.applying(child.localTransform.inverted())

            if let hit = child.hitTest(localPoint, tolerance: tolerance) {
                // If the child is hit, we return its result directly. The child is
                // responsible for converting the hit location to world space.
                return hit
            }
        }
        
        // Base implementation doesn't hit itself, only its children.
        return nil
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
