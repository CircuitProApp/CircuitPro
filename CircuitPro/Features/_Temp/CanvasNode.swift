import CoreGraphics
import AppKit

/// The core protocol for any object that can exist on the canvas scene graph.
///
/// It defines an object that has an identity, can be drawn and interacted with,
/// occupies a bounding box, and exists within a parent-child hierarchy.
/// It is class-bound to support reference semantics required for a graph structure.
protocol CanvasNode: AnyObject, Identifiable, Drawable, Hittable, Bounded, Transformable {

    // MARK: - Scene Graph API

    /// A weak reference to the parent node. This must be weak to prevent retain cycles.
    /// The type is `any CanvasNode` to allow for heterogenous parenting.
    var parent: (any CanvasNode)? { get set }

    /// An array of child nodes.
    /// The type is `any CanvasNode` to allow for a mix of different node types (e.g., a symbol holding text).
    var children: [any CanvasNode] { get set }

    /// A flag indicating whether the node and its children are visible.
    var isVisible: Bool { get set }

    /// The node's transformation (position, rotation, scale) relative to its parent's coordinate space.
    var localTransform: CGAffineTransform { get }
    
    /// The node's absolute transformation, calculated by concatenating its local transform
    /// with all of its ancestors' transforms up to the root.
    var worldTransform: CGAffineTransform { get }


    // MARK: - Hierarchy Management

    /// Adds a node as a child of the current node.
    ///
    /// This method will automatically handle setting the child's parent and removing it
    /// from its previous parent if one exists.
    /// - Parameter node: The `CanvasNode` to add.
    func addChild(_ node: any CanvasNode)

    /// Removes the current node from its parent.
    func removeFromParent()
    
    
    // MARK: - Coordinate Space Conversion

    /// Converts a point from the coordinate system of another node to this node's coordinate system.
    /// - Parameters:
    ///   - point: A point in the coordinate system of the `sourceNode`.
    ///   - sourceNode: The node in whose coordinate system `point` is specified. Pass `nil` to specify the scene's root coordinate system (world space).
    /// - Returns: The point converted to this node's local coordinate system.
    func convert(_ point: CGPoint, from sourceNode: (any CanvasNode)?) -> CGPoint
    
    /// Converts a point from this node's coordinate system to the coordinate system of another node.
    /// - Parameters:
    ///   - point: A point in this node's local coordinate system.
    ///   - destinationNode: The node into whose coordinate system `point` should be converted. Pass `nil` to specify the scene's root coordinate system (world space).
    /// - Returns: The point converted to the `destinationNode`'s coordinate system.
    func convert(_ point: CGPoint, to destinationNode: (any CanvasNode)?) -> CGPoint
}
