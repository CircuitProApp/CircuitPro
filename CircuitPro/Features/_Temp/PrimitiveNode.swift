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
        // Delegate hit-testing.
        // We pass the point directly, as this top-level node's local space is world space.
        return primitive.hitTest(point, tolerance: tolerance)
    }
}
