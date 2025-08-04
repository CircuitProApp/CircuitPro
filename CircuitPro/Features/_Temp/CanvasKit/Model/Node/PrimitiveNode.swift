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
    
    init(primitive: AnyPrimitive) {
        self.primitive = primitive
        
        // --- THIS IS THE FIX ---
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
    
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // The point received here is already in this node's local space.
        // We pass it directly to the underlying primitive for the geometry check.
        guard let localHit = primitive.hitTest(point, tolerance: tolerance) else {
            return nil
        }
        
        // The localHit's position is relative to the primitive's origin (0,0).
        // We must convert this to world coordinates for the final result.
        let worldPosition = point.applying(self.worldTransform)

        // Construct the final target, replacing the local position with the world position.
        return CanvasHitTarget(
            partID: localHit.partID,
            ownerPath: localHit.ownerPath,
            kind: localHit.kind,
            position: worldPosition
        )
    }
}
