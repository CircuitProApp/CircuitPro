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

        // map the probe into the symbol’s local space
        let localPoint = worldPoint.applying(
            CGAffineTransform(translationX: position.x, y: position.y)
                .rotated(by: rotation)
                .inverted()
        )

        // 1. Check for pin hits first, as they are more specific.
        for pin in symbol.pins {
            if pin.hitTest(localPoint, tolerance: tolerance) != nil {
                // A pin was hit. We need to transform its local position back to world space.
                let worldPinPosition = pin.position.applying(
                    CGAffineTransform(translationX: position.x, y: position.y)
                    .rotated(by: rotation)
                )
                return .canvasElement(part: .pin(id: pin.id, parentSymbolID: id, position: worldPinPosition))
            }
        }

        // 2. If no pin was hit, check the main body primitives.
        for primitive in symbol.primitives {
            if primitive.hitTest(localPoint, tolerance: tolerance) != nil {
                return .canvasElement(part: .body(id: id))
            }
        }
        
        // 3. No hit.
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
