//
//  PrimitiveNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import CoreGraphics

/// A scene graph node that represents a single, editable graphic primitive on the canvas.
///
/// This class acts as a wrapper around an `AnyPrimitive` struct, giving it an identity
/// and a place within the scene graph hierarchy. It delegates drawing, hit-testing,
/// and bounding box calculations to its underlying primitive model.
class PrimitiveNode: BaseNode {

    // The underlying data model for this node.
    var primitive: AnyPrimitive

    override var position: CGPoint {
        get { primitive.position }
        set { primitive.position = newValue }
    }

    override var rotation: CGFloat {
        get { primitive.rotation }
        set { primitive.rotation = newValue }
    }
    
    // --- THIS IS A NEW PROPERTY FROM OUR PREVIOUS DISCUSSION ---
    /// A `PrimitiveNode` is always considered selectable.
    override var isSelectable: Bool {
        return true
    }

    init(primitive: AnyPrimitive) {
        self.primitive = primitive
        
        // We pass the primitive's ID to the superclass initializer.
        // This guarantees the PrimitiveNode and its underlying primitive
        // share the exact same ID.
        super.init(id: primitive.id)
    }

    // MARK: - Protocol Overrides
    
    override func makeBodyParameters() -> [DrawingParameters] {
        return primitive.makeBodyParameters()
    }
    
    override func makeHaloPath() -> CGPath? {
        return primitive.makeHaloPath()
    }
    
    override var boundingBox: CGRect {
        return primitive.boundingBox
    }
    
    
    var displayName: String {
        primitive.displayName
    }

    var symbol: String {
        primitive.symbol
    }
    
    // --- THIS IS THE UPDATED HIT-TEST METHOD ---
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // The 'point' is already in this node's local coordinate space.

        // 1. Delegate the geometry check to the underlying primitive.
        //    We expect an `AnyHashable?` back, not a full CanvasHitTarget.
        guard let partId = primitive.hitTest(point, tolerance: tolerance) else {
            // The primitive's geometry wasn't hit.
            return nil
        }
        
        // 2. The primitive was hit. This node now builds the generic CanvasHitTarget.
        return CanvasHitTarget(
            // The node that was hit is this instance of PrimitiveNode.
            node: self,
            // The specific part that was hit is whatever the primitive returned.
            partIdentifier: partId,
            // Convert the local hit point to world coordinates for the final result.
            position: point.applying(self.worldTransform)
        )
    }
}

// MARK: - Handle Editing Conformance
extension PrimitiveNode: HandleEditable {
    
    func handles() -> [Handle] {
        // Delegate directly to the wrapped AnyPrimitive.
        return primitive.handles()
    }

    func updateHandle(_ kind: Handle.Kind, to position: CGPoint, opposite frozenOpposite: CGPoint?) {
        // AnyPrimitive is a value type (enum), so calling a mutating method
        // on the 'primitive' property modifies it in place.
        primitive.updateHandle(kind, to: position, opposite: frozenOpposite)
        
        // Trigger a redraw to reflect the change.
        self.onNeedsRedraw?()
    }
}
