import CoreGraphics
import AppKit

/// The core protocol for any object that can exist on the canvas scene graph.
///
/// It defines an object that has an identity, can be drawn and interacted with,
/// occupies a bounding box, and exists within a parent-child hierarchy.
/// It conforms to `Hashable` to allow nodes to be stored in sets and dictionaries.
protocol CanvasNode: AnyObject, CanvasElement {

    // MARK: - Scene Graph API

    /// A weak reference to the parent node. This must be weak to prevent retain cycles.
    var parent: (any CanvasNode)? { get set }

    /// An array of child nodes.
    var children: [any CanvasNode] { get set }
    

    var isVisible: Bool { get set }
    
    var localTransform: CGAffineTransform { get }
    var worldTransform: CGAffineTransform { get }
    func addChild(_ node: any CanvasNode)
    func removeFromParent()
    func convert(_ point: CGPoint, from sourceNode: (any CanvasNode)?) -> CGPoint
    func convert(_ point: CGPoint, to destinationNode: (any CanvasNode)?) -> CGPoint
}

// MARK: - Global Equatable Conformance

/// Provides the required `==` implementation to compare two `any CanvasNode` types.
/// Two nodes are considered equal if they have the same unique ID. This is the foundation
/// for the `Hashable` conformance.
func == (lhs: any CanvasNode, rhs: any CanvasNode) -> Bool {
    return lhs.id == rhs.id
}
