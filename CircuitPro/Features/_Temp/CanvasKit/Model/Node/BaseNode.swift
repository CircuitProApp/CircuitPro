//
//  BaseNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import CoreGraphics
import AppKit

/// A concrete implementation of the `CanvasNode` protocol that provides the fundamental
/// behaviors required for a scene graph, including hierarchy management and transform calculation.
class BaseNode: CanvasNode {

    // MARK: - Stored Properties
    
    let id: UUID
    
    // --- FIX 1: Use concrete BaseNode type and add redraw callback ---
    weak var parent: BaseNode?
    var children: [BaseNode] = []
    
    /// A callback closure that the node can trigger to notify the canvas that it needs to be redrawn.
    /// This is set by the CanvasController when the node is added to the scene.
    var onNeedsRedraw: (() -> Void)?
    
    var isVisible: Bool = true
    
    // --- Overridable Properties ---
    
    /// Determines if the user can select this node directly.
    /// Subclasses should override this. A `PrimitiveNode` might be selectable,
    /// but a `PinNode` that's part of a larger symbol might not be.
    var isSelectable: Bool {
        return true
    }
    
    /// The node's position relative to its parent's origin.
    /// Subclasses (like `PinNode`) must override this to get/set their underlying model's position.
    var position: CGPoint {
        get { .zero }
        set { /* Base implementation does nothing. */ }
    }

    /// The node's rotation in radians.
    /// Subclasses (like `PinNode`) must override this to get/set their underlying model's rotation.
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

    func makeBodyParameters() -> [DrawingParameters] {
        return [] // Base node has no appearance.
    }
    
    func makeHaloPath() -> CGPath? {
        let box = self.boundingBox
        guard !box.isNull else { return nil }
        return CGPath(rect: box, transform: nil)
    }

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        guard self.isVisible else { return nil }

        // --- FIX 2: Simplified Hit-Testing Logic ---
        // The children array is now `[BaseNode]`, so no casting is needed.
        for child in children.reversed() {
            let localPoint = point.applying(child.localTransform.inverted())
            if let hit = child.hitTest(localPoint, tolerance: tolerance) {
                return hit
            }
        }
        return nil
    }

    var boundingBox: CGRect {
        // --- FIX 3: Simplified Bounding Box Logic ---
        // The children array is now `[BaseNode]`, so no casting is needed.
        let childBoxes = children.compactMap { child -> CGRect? in
            guard child.isVisible else { return nil }
            return child.boundingBox.applying(child.localTransform)
        }
        return childBoxes.reduce(CGRect.null) { $0.union($1) }
    }
}
