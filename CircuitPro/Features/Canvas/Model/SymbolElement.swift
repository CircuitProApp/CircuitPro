//
//  SymbolElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct SymbolElement: Identifiable {

    let id: UUID

    // MARK: Instance-specific data
    var instance: SymbolInstance     // position, rotation … (mutable)

    // MARK: Library master (immutable, reference type → no copy cost)
    let symbol: Symbol

    var primitives: [AnyPrimitive] {
        symbol.primitives + symbol.pins.flatMap(\.primitives)
    }

}

// ═══════════════════════════════════════════════════════════════════════
//  Equality & Hashing based solely on the element’s id
// ═══════════════════════════════════════════════════════════════════════
extension SymbolElement: Equatable, Hashable {
    static func == (lhs: SymbolElement, rhs: SymbolElement) -> Bool {
        // An element is only truly equal if its instance data (like position) is also the same.
        // This is critical for the rendering system to detect changes and redraw elements that have moved.
        lhs.id == rhs.id && lhs.instance == rhs.instance
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SymbolElement: Transformable {

    var position: CGPoint {
        get { instance.position }
        set {
            // To maintain value semantics for the struct, we must replace the
            // reference type property with a new copy containing the change.
            // This ensures that struct mutation is correctly detected by views.
            let newInstance = instance.copy()
            newInstance.position = newValue
            self.instance = newInstance
        }
    }

    var rotation: CGFloat {
        get { instance.rotation }
        set {
            let newInstance = instance.copy()
            newInstance.rotation = newValue
            self.instance = newInstance
        }
    }
}

extension SymbolElement {
    var transform: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
    }
}

extension SymbolElement: Drawable {
    
    /// Generates the drawing parameters for the symbol's entire body, including all child primitives and pins,
    /// transformed into world space.
    func makeBodyParameters() -> [DrawingParameters] {
        // 1. Define the instance's world transform
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
        
        var allParameters: [DrawingParameters] = []

        // 2. Process master primitives
        // Ask each primitive for its parameters and apply the symbol's transform to the path.
        let masterPrimitiveParams = symbol.primitives.flatMap { $0.makeBodyParameters() }
        for params in masterPrimitiveParams {
            if let transformedPath = params.path.copy(using: &transform) {
                // Create a new DrawingParameters with the transformed path
                allParameters.append(DrawingParameters(
                    path: transformedPath,
                    lineWidth: params.lineWidth,
                    fillColor: params.fillColor,
                    strokeColor: params.strokeColor,
                    lineDashPattern: params.lineDashPattern,
                    lineCap: params.lineCap,
                    lineJoin: params.lineJoin
                ))
            }
        }
        
        // 3. Process pins
        // Pins are also composite, so we do the same for all parameters they return.
        let pinParams = symbol.pins.flatMap { $0.makeBodyParameters() }
        for params in pinParams {
            if let transformedPath = params.path.copy(using: &transform) {
                // Create a new DrawingParameters with the transformed path
                allParameters.append(DrawingParameters(
                    path: transformedPath,
                    lineWidth: params.lineWidth,
                    fillColor: params.fillColor,
                    strokeColor: params.strokeColor,
                    lineDashPattern: params.lineDashPattern,
                    lineCap: params.lineCap,
                    lineJoin: params.lineJoin
                ))
            }
        }
        
        return allParameters
    }
    
    /// Generates a single, unified outline for the selection halo, transformed into world space.
    func makeHaloParameters() -> DrawingParameters? {
        let combinedPath = CGMutablePath()
        
        // 1. Collect all halo paths from children (primitives and pins)
        let childHaloables = symbol.primitives as [any Drawable] + symbol.pins as [any Drawable]
        for child in childHaloables {
            if let haloParams = child.makeHaloParameters() {
                combinedPath.addPath(haloParams.path)
            }
        }
        
        guard !combinedPath.isEmpty else { return nil }
        
        // 2. Apply the symbol's instance transform to the unified path
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
        
        guard let finalPath = combinedPath.copy(using: &transform) else {
            return nil
        }
        
        // 3. Return the final drawing parameters for the halo
        return DrawingParameters(
            path: finalPath,
            lineWidth: 4.0, // Standard halo width
            fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        )
    }
}

extension SymbolElement: Hittable {

    func hitTest(_ worldPoint: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {

        // 1. Transform the world-space point into the symbol's local coordinate space.
        let localPoint = worldPoint.applying(self.transform.inverted())

        // 2. Check for pin hits first.
        for pin in symbol.pins {
            // Recursively call hitTest on the child pin.
            if let pinHitResult = pin.hitTest(localPoint, tolerance: tolerance) {
                
                // A pin was hit. We now construct a NEW CanvasHitTarget.
                // We build a new owner path by prepending our symbol's ID to the path from the pin.
                let newOwnerPath = [self.id] + pinHitResult.ownerPath
                
                // Return a new, fully-contextualized hit record.
                return CanvasHitTarget(
                    partID: pinHitResult.partID,    // The specific pin that was hit.
                    ownerPath: newOwnerPath,        // The newly constructed hierarchical path.
                    kind: pinHitResult.kind,        // The kind of object hit (a .pin).
                    position: worldPoint            // The original hit position in world space.
                )
            }
        }

        // 3. If no pin was hit, check the general body primitives.
        for primitive in symbol.primitives {
            // Recursively call hitTest on the child primitive.
            if let primitiveHitResult = primitive.hitTest(localPoint, tolerance: tolerance) {
                
                // A primitive was hit. We construct a NEW CanvasHitTarget.
                let newOwnerPath = [self.id] + primitiveHitResult.ownerPath
                
                // Return a new result, preserving the original hit part and kind,
                // but updating the path and ensuring the position is in world space.
                return CanvasHitTarget(
                    partID: primitiveHitResult.partID,
                    ownerPath: newOwnerPath,
                    kind: primitiveHitResult.kind,
                    position: worldPoint
                )
            }
        }
        
        // 4. If neither pins nor primitives were hit, the symbol was missed.
        return nil
    }
}

extension SymbolElement: Bounded {

    // 1 Axis-aligned box in world space
    var boundingBox: CGRect {

        // 1.1 Local-to-world transform shared by every child
        let transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        // 1.2 Local boxes of master primitives and pins
        let localBoxes = symbol.primitives.map(\.boundingBox) +
                         symbol.pins.map(\.boundingBox)

        // 1.3 Union after mapping each box into world space
        return localBoxes
            .map { $0.transformed(by: transform) }
            .reduce(CGRect.null) { $0.union($1) }
    }
}

private extension CGRect {

    // 1 Transformed axis-aligned bounding box
    func transformed(by transform: CGAffineTransform) -> CGRect {

        // 1.1 Corners in local space
        let corners = [
            origin,
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY)
        ]

        // 1.2 Map every corner and grow a rectangle around them
        var out = CGRect.null
        for point in corners.map({ $0.applying(transform) }) {
            out = out.union(CGRect(origin: point, size: .zero))
        }
        return out
    }
}
