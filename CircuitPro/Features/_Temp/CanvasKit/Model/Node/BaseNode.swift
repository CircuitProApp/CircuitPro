//
//  BaseNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import CoreGraphics
import AppKit
import Observation

/// A concrete implementation of the `CanvasNode` protocol that provides the fundamental
/// behaviors required for a scene graph, including hierarchy management and transform calculation.
class BaseNode: CanvasNode {

    // MARK: - Stored Properties
    
    let id: UUID
    
    weak var parent: BaseNode?
    var children: [BaseNode] = []
    
    /// A callback closure that the node can trigger to notify the canvas that it needs to be redrawn.
    /// This is set by the CanvasController when the node is added to the scene.
    var onNeedsRedraw: (() -> Void)?
    
    var isVisible: Bool = true
    
    private var _cachedLocalContentBoundingBox: CGRect?
    
    // Overridable Properties
    
    /// Determines if the user can select this node directly.
    var isSelectable: Bool {
        return true
    }
    
    /// The node's position relative to its parent's origin.
    var position: CGPoint {
        get { .zero }
        set { /* Base implementation does nothing. */ }
    }

    /// The node's rotation in radians.
    var rotation: CGFloat {
        get { 0.0 }
        set { /* Base implementation does nothing. */ }
    }
    
    init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: - Hierarchy Management

    func addChild(_ node: BaseNode) {
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
    
    // MARK: - Hashable & Equatable Conformance

    static func == (lhs: BaseNode, rhs: BaseNode) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Coordinate Space Conversion

    func convert(_ point: CGPoint, from sourceNode: BaseNode?) -> CGPoint {
        let sourceTransform = sourceNode?.worldTransform ?? .identity
        let destinationTransform = self.worldTransform
        let worldPoint = point.applying(sourceTransform)
        return worldPoint.applying(destinationTransform.inverted())
    }

    func convert(_ point: CGPoint, to destinationNode: BaseNode?) -> CGPoint {
        let sourceTransform = self.worldTransform
        let destinationTransform = destinationNode?.worldTransform ?? .identity
        let worldPoint = point.applying(sourceTransform)
        return worldPoint.applying(destinationTransform.inverted())
    }

    // MARK: - Overridable Drawing & Interaction (Default Implementations)

    func makeDrawingPrimitives() -> [DrawingPrimitive] {
        return [] // Base node has no appearance.
    }
    
    func makeHaloPath() -> CGPath? {
        return nil
    }

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        guard self.isVisible else { return nil }

        for child in children.reversed() {
            let localPoint = point.applying(child.localTransform.inverted())
            if let hit = child.hitTest(localPoint, tolerance: tolerance) {
                return hit
            }
        }
        return nil
    }
    
    func nodes(intersecting rect: CGRect) -> [BaseNode] {
        var foundNodes: [BaseNode] = []
        
        // 1. Check if this node itself is selectable and intersects
        if self.isSelectable {
            // Get the node's interaction bounds in world coordinates
            let worldBounds = self.interactionBounds.applying(self.worldTransform)
            if !worldBounds.isNull && rect.intersects(worldBounds) {
                foundNodes.append(self)
            }
        }
        
        // 2. Recursively check all children
        // This is the default container behavior.
        for child in children where child.isVisible {
            foundNodes.append(contentsOf: child.nodes(intersecting: rect))
        }
        
        return foundNodes
    }

    /// The bounding box of the content drawn directly by this node, in its local coordinate space.
     /// This is calculated from the node's drawing primitives and is cached for performance.
     private var localContentBoundingBox: CGRect {
         // Return the cached value if it exists.
         if let cached = _cachedLocalContentBoundingBox {
             return cached
         }

         // If no cache, calculate it from the drawing primitives.
         let primitives = self.makeDrawingPrimitives()
         var box = CGRect.null

         for primitive in primitives {
             switch primitive {
             case .fill(let path, _, _):
                 box = box.union(path.boundingBoxOfPath)
             case .stroke(let path, _, let lineWidth, _, _, _, _):
                 // For strokes, we must account for the line width.
                 let strokeBox = path.boundingBoxOfPath.insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2)
                 box = box.union(strokeBox)
             }
         }
         
         // Store the result in the cache and return it.
         _cachedLocalContentBoundingBox = box
         return box
     }

     /// The node's total bounding box in its LOCAL coordinate space.
     /// This is the union of its own content and all of its children's bounding boxes.
     var boundingBox: CGRect {
         // 1. Start with the bounding box of this node's own content.
         var combinedBox = self.localContentBoundingBox

         // 2. Iterate over all visible children.
         for child in children where child.isVisible {
             // Get the child's total bounding box (which is in its own local space).
             let childBox = child.boundingBox
             // Transform the child's box into our coordinate space.
             let transformedChildBox = childBox.applying(child.localTransform)
             // Union it with our combined box.
             combinedBox = combinedBox.union(transformedChildBox)
         }
         
         return combinedBox
     }
    
    var interactionBounds: CGRect {
        // The default implementation returns the full visual bounding box.
        return self.boundingBox
    }
}
