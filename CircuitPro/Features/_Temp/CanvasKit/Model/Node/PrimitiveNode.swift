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

    init(primitive: AnyPrimitive) {
        self.primitive = primitive
        super.init()

        // Initialize the node's transform from the primitive's initial state.
        self.position = primitive.position
        self.rotation = primitive.rotation
    }

    // MARK: - Protocol Overrides
    
    override func makeBodyParameters() -> [DrawingParameters] {
        // Delegate drawing directly to the primitive struct.
        return primitive.makeBodyParameters()
    }
    
    override func makeHaloPath() -> CGPath? {
        // Delegate halo path generation.
        return primitive.makeHaloPath()
    }
    
    override var boundingBox: CGRect {
        // Delegate bounding box calculation.
        return primitive.boundingBox
    }
    
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // --- THIS IS THE FIX ---

        // The 'point' parameter is in WORLD space (i.e., the parent's space).
        // The underlying primitive expects a point in its own LOCAL space.
        
        // 1. Create a transform to map points from world space to this node's local space.
        let inverseTransform = self.localTransform.inverted()
        
        // 2. Apply it to the incoming point.
        let localPoint = point.applying(inverseTransform)
        
        // 3. Perform the hit test using the correctly transformed point.
        guard let hitResult = primitive.hitTest(localPoint, tolerance: tolerance) else {
            return nil
        }
        
        // 4. The hitResult's position is in local space. We must return a new
        //    hit target that contains the original world-space position.
        return CanvasHitTarget(
            partID: hitResult.partID,
            ownerPath: hitResult.ownerPath,
            kind: hitResult.kind,
            position: point // Use the original world-space point for the final result
        )
    }
}
