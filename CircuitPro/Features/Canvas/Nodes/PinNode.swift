//
//  PinNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit

/// A scene graph node that represents a `Pin` data model on the canvas.
///
/// This class is the `CanvasElement`. It wraps a `Pin` struct and is responsible for
/// all drawing and hit-testing logic by using the geometry calculations defined
/// in the `Pin+Geometry` extension.
class PinNode: BaseNode {
    
    // MARK: - Properties
    
    /// The underlying data model for this node.
    var pin: Pin
    
    /// Defines the distinct, hittable parts of a PinNode for rich interaction.
    enum Part: Hashable {
        case endpoint
        case body
        case nameLabel
        case numberLabel
    }
    
    override var isSelectable: Bool {
        // A pin is not selectable if its parent is a SymbolNode.
        return !(parent is SymbolNode)
    }
    
    // MARK: - Overridden Scene Graph Properties
    
    override var position: CGPoint {
        get { pin.position }
        set { pin.position = newValue }
    }
    
    override var rotation: CGFloat {
        get { 0 } // Always return 0 to prevent the scene graph from rotating our content.
        set {
            // The pin's rotation is part of its data model, so we set it here.
            // The drawing code will read this value directly.
            pin.rotation = newValue
        }
    }
    
    init(pin: Pin) {
        self.pin = pin
        super.init(id: pin.id)
    }
    
    // --- FIX 2: Update drawing to use the pin's world-coordinate parameters ---
    // This is now almost identical to the logic in the old Pin+Drawable.
    override func makeBodyParameters() -> [DrawingParameters] {
        return pin.makeAllBodyParameters() // Delegate all drawing logic to the pin.
    }
    
    override func makeHaloPath() -> CGPath? {
        return pin.calculateCompositePath()
    }
    
    // MARK: - Hittable Conformance (Now Using Local Geometry)
    
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        let inflatedTolerance = tolerance * 2.0 // Use a larger tolerance for easier interaction

        // --- Priority 1: Test for the most specific parts first ---

        // Did the user click the connection point?
        // We correctly access the radius from the model: `self.pin.endpointRadius`.
        let endpointRect = CGRect(x: -self.pin.endpointRadius, y: -self.pin.endpointRadius, width: self.pin.endpointRadius * 2, height: self.pin.endpointRadius * 2)
        if endpointRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
            return CanvasHitTarget(
                node: self,
                partIdentifier: Part.endpoint,
                position: self.convert(.zero, to: nil)
            )
        }
        
        // Did the user click the number?
        if self.pin.showNumber {
            var (path, transform) = self.pin.numberLayout()
            if let finalPath = path.copy(using: &transform) {
                if finalPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
                    return CanvasHitTarget(node: self, partIdentifier: Part.numberLabel, position: self.convert(point, to: nil))
                }
            }
        }
        
        // Did the user click the name label?
        if self.pin.showLabel && !self.pin.name.isEmpty {
            var (path, transform) = self.pin.labelLayout()
            if let finalPath = path.copy(using: &transform) {
                if finalPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
                    return CanvasHitTarget(node: self, partIdentifier: Part.nameLabel, position: self.convert(point, to: nil))
                }
            }
        }
        
        // --- Priority 2: Fallback to the physical body (leg only) ---
        
        // If no specific part was hit, we check just the pin's leg.
        // We construct this path manually to avoid re-testing the endpoint or text.
        let legPath = CGMutablePath()
        legPath.move(to: self.pin.localLegStart)
        legPath.addLine(to: .zero)
        
        if legPath.copy(strokingWithWidth: inflatedTolerance, lineCap: .round, lineJoin: .round, miterLimit: 1).contains(point) {
            return CanvasHitTarget(
                node: self,
                partIdentifier: Part.body,
                position: self.convert(point, to: nil)
            )
        }
        
        // If nothing was hit, return nil.
        return nil
    }
}
