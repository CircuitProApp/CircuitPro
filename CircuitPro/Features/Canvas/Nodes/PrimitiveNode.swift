// PrimitiveNode.swift

import CoreGraphics
import Observation
import SwiftUI

/// A scene graph node that represents a single, editable graphic primitive on the canvas.
/// This class acts as a wrapper around an `AnyPrimitive` struct, giving it an identity
/// and a place within the scene graph hierarchy.
@Observable
class PrimitiveNode: BaseNode, Layerable {
    
    var primitive: AnyCanvasPrimitive
    
    // MARK: - Protocol Conformances
    
    override var position: CGPoint {
        get { primitive.position }
        set { primitive.position = newValue }
    }
    
    override var rotation: CGFloat {
        get { primitive.rotation }
        set { primitive.rotation = newValue }
    }
    
    var layerId: UUID? {
         get { primitive.layerId }
         set { primitive.layerId = newValue }
     }
    
    override var isSelectable: Bool {
          return !(parent is SymbolNode || parent is FootprintNode)
      }
    
    // MARK: - Init
    
    init(primitive: AnyCanvasPrimitive) {
        self.primitive = primitive
        super.init(id: primitive.id)
    }
    
    // MARK: - Drawing & Interaction Overrides
    
    /// This default `Drawable` implementation is now intentionally unsafe for `PrimitiveNode`.
    /// The renderer must call the primitive's specialized `makeDrawingPrimitives(with:)` method
    /// after resolving the node's color.
    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        fatalError("`PrimitiveNode` cannot be drawn directly. The renderer must resolve its color and use the primitive's 'makeDrawingPrimitives(with:)' method.")
    }
    
    /// The node's halo path is delegated to the primitive.
    override func makeHaloPath() -> CGPath? {
        return primitive.makeHaloPath()
    }
    
    /// The node's bounding box is delegated to the primitive.
    override var boundingBox: CGRect {
        return primitive.boundingBox
    }
    
    var displayName: String {
        primitive.displayName
    }
    
    var symbol: String {
        primitive.symbol
    }
    
    /// The node's hit-test logic is delegated to the primitive.
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        guard let partId = primitive.hitTest(point, tolerance: tolerance) else {
            return nil
        }
        
        return CanvasHitTarget(
            node: self,
            partIdentifier: partId,
            position: point.applying(self.worldTransform)
        )
    }
}

extension PrimitiveNode: HandleEditable {
    
    func handles() -> [CanvasHandle] {
        // Delegate directly to the wrapped AnyPrimitive.
        return primitive.handles()
    }
    
    func updateHandle(_ kind: CanvasHandle.Kind, to position: CGPoint, opposite frozenOpposite: CGPoint?) {
        // AnyPrimitive is a value type (enum), so calling a mutating method
        // on the 'primitive' property modifies it in place.
        primitive.updateHandle(kind, to: position, opposite: frozenOpposite)
    }
}
