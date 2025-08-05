//
//  SymbolElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct SymbolElement: Identifiable {
    
    let id: UUID
    var instance: SymbolInstance
    let symbol: Symbol
    var reference: String
    var properties: [ResolvedProperty]

    // This array now holds the final, display-ready canvas elements.
    var anchoredTexts: [AnchoredTextElement]

    var primitives: [AnyPrimitive] {
        symbol.primitives /*+ symbol.pins.flatMap(\.primitives)*/
    }

    // The initializer is now much simpler. It accepts fully resolved text data.
    init(
        id: UUID,
        instance: SymbolInstance,
        symbol: Symbol,
        reference: String,
        properties: [ResolvedProperty],
        resolvedTexts: [ResolvedText] // New parameter
    ) {
        self.id = id
        self.instance = instance
        self.symbol = symbol
        self.reference = reference
        self.properties = properties
        
        // The complex resolution logic is GONE. We simply map the resolved data
        // into the final canvas elements that know how to draw themselves.
        let symbolTransform = CGAffineTransform(translationX: instance.position.x, y: instance.position.y)
            .rotated(by: instance.rotation)
            
        self.anchoredTexts = resolvedTexts.map { resolvedText -> AnchoredTextElement in
            AnchoredTextElement(
                resolvedText: resolvedText,
                parentID: id,
                parentTransform: symbolTransform
            )
        }
    }
}

// MARK: - Conformance (Equatable, Hashable, etc.)
// These remain unchanged as they correctly operate on the updated `SymbolElement` properties.

extension SymbolElement: Equatable, Hashable {
    static func == (lhs: SymbolElement, rhs: SymbolElement) -> Bool {
        // Compare all properties that define the visual state of the element.
        lhs.id == rhs.id &&
        lhs.instance == rhs.instance &&
        lhs.reference == rhs.reference &&
        lhs.properties == rhs.properties &&
        // THIS IS THE CRITICAL FIX:
        lhs.anchoredTexts == rhs.anchoredTexts
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SymbolElement: Transformable {
    var position: CGPoint {
        get { instance.position }
        set {
            // 1. Calculate the delta of the move.
            let delta = newValue - self.position
            
            // 2. Create a new SymbolInstance with the new position.
            let newInstance = instance.copy()
            newInstance.position = newValue
            self.instance = newInstance

            // 3. Apply the *same delta* to all child text elements.
            //    This moves them in lock-step with the parent.
            for i in anchoredTexts.indices {
                anchoredTexts[i].position += delta
                anchoredTexts[i].anchorPosition += delta // Also move the visual anchor point
            }
        }
    }

    var rotation: CGFloat {
        get { instance.rotation }
        set {
            // Rotation is more complex because it pivots around an origin.
            // The simplest, most robust way is to regenerate the texts.
            let newInstance = instance.copy()
            newInstance.rotation = newValue
            self.instance = newInstance
            
            // We call our new, efficient position updater.
            updateAnchoredTextPositions()
        }
    }
}
// Add this new private helper method to the main SymbolElement struct or in a private extension.
private extension SymbolElement {
    
    /// Efficiently updates the world coordinates of all child text elements after the parent symbol moves or rotates.
    /// This replaces the expensive `resolveAnchoredTexts` method for simple transformations.
    mutating func updateAnchoredTextPositions() {
        // Get the parent symbol's new transform.
        let newParentTransform = self.transform

        // Create a new array to store the updated text elements.
        var updatedTexts: [AnchoredTextElement] = []
        
        // Iterate through the existing text elements.
        for var canvasText in self.anchoredTexts {
            // Reconstruct the original resolved data to get the relative positions.
            // This is necessary because the canvas element only stores absolute positions.
            let resolvedText = canvasText.toResolvedText(parentTransform: newParentTransform)
            
            // Recalculate the absolute world positions using the new transform.
            canvasText.anchorPosition = resolvedText.anchorRelativePosition.applying(newParentTransform)
            canvasText.textElement.position = resolvedText.relativePosition.applying(newParentTransform)
            canvasText.textElement.rotation = newParentTransform.rotationAngle // Match parent rotation
            
            updatedTexts.append(canvasText)
        }
        
        // Replace the old array with the updated one.
        self.anchoredTexts = updatedTexts
    }
}

// Helper to extract rotation from CGAffineTransform
private extension CGAffineTransform {
    var rotationAngle: CGFloat {
        return atan2(b, a)
    }
}

extension SymbolElement {
    var transform: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
    }
}

// MARK: - Drawing & Hit-Testing
// The below code for drawing, hit-testing, and bounding boxes does not need
// to change, as it correctly consumes the `primitives` and `anchoredTexts` arrays
// that are resolved by the logic above.

//extension SymbolElement: Drawable {
//    func makeBodyParameters() -> [DrawingParameters] {
//        var allParameters: [DrawingParameters] = []
//        var symbolTransform = self.transform
//
//        // 1. Process primitives and pins (defined in local space).
//        let childDrawables = (symbol.primitives as [any Drawable]) + (symbol.pins as [any Drawable])
//        for drawable in childDrawables {
//            for params in drawable.makeBodyParameters() {
//                if let transformedPath = params.path.copy(using: &symbolTransform) {
//                    allParameters.append(DrawingParameters(
//                        path: transformedPath,
//                        lineWidth: params.lineWidth,
//                        fillColor: params.fillColor,
//                        strokeColor: params.strokeColor,
//                        lineDashPattern: params.lineDashPattern,
//                        lineCap: params.lineCap,
//                        lineJoin: params.lineJoin,
//                        fillRule: params.fillRule
//                    ))
//                }
//            }
//        }
//        
//        // 2. Process anchored texts (already in world space).
//        for textElement in anchoredTexts {
//            allParameters.append(contentsOf: textElement.makeBodyParameters())
//        }
//        
//        return allParameters
//    }
//    
//    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
//        let finalPath = CGMutablePath()
//        
//        if selectedIDs.contains(self.id) {
//            let localHaloPath = CGMutablePath()
//            let localDrawables = (symbol.primitives as [any Drawable]) + (symbol.pins as [any Drawable])
//            for child in localDrawables {
//                if let path = child.makeHaloPath() {
//                    localHaloPath.addPath(path)
//                }
//            }
//            var symbolTransform = self.transform
//            if let transformedHalo = localHaloPath.copy(using: &symbolTransform) {
//                finalPath.addPath(transformedHalo)
//            }
//            
//            for textElement in anchoredTexts {
//                if let path = textElement.textElement.makeHaloPath() {
//                    finalPath.addPath(path)
//                }
//            }
//            
//        } else {
//            for textElement in anchoredTexts {
//                if let textHaloParams = textElement.makeHaloParameters(selectedIDs: selectedIDs) {
//                    finalPath.addPath(textHaloParams.path)
//                }
//            }
//        }
//        
//        guard !finalPath.isEmpty else { return nil }
//        
//        return DrawingParameters(
//            path: finalPath, lineWidth: 4.0, fillColor: nil,
//            strokeColor: NSColor.systemBlue.withAlphaComponent(0.3).cgColor
//        )
//    }
//}
//
//extension SymbolElement: Hittable {
//    func hitTest(_ worldPoint: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
//        let localPoint = worldPoint.applying(self.transform.inverted())
////        
////        for textElement in anchoredTexts {
////            if let textHitResult = textElement.hitTest(worldPoint, tolerance: tolerance) {
////                let newOwnerPath = [self.id] + textHitResult.ownerPath
////                return CanvasHitTarget(
////                    partID: textHitResult.partID, ownerPath: newOwnerPath,
////                    kind: textHitResult.kind, position: worldPoint
////                )
////            }
////        }
////        
////        for pin in symbol.pins {
////            if let pinHitResult = pin.hitTest(localPoint, tolerance: tolerance) {
////                let newOwnerPath = [self.id] + pinHitResult.ownerPath
////                return CanvasHitTarget(
////                    partID: pinHitResult.partID, ownerPath: newOwnerPath,
////                    kind: pinHitResult.kind, position: worldPoint
////                )
////            }
////        }
////
////        for primitive in symbol.primitives {
////            if let primitiveHitResult = primitive.hitTest(localPoint, tolerance: tolerance) {
////                let newOwnerPath = [self.id] + primitiveHitResult.ownerPath
////                return CanvasHitTarget(
////                    partID: primitiveHitResult.partID, ownerPath: newOwnerPath,
////                    kind: primitiveHitResult.kind, position: worldPoint
////                )
////            }
////        }
//        return nil
//    }
//}
//
//extension SymbolElement: Bounded {
//    var boundingBox: CGRect {
//        let transform = self.transform
//        let localBoxes = symbol.primitives.map(\.boundingBox) + symbol.pins.map(\.boundingBox)
//        let transformedBoxes = localBoxes.map { $0.transformed(by: transform) }
//        let textBoxes = anchoredTexts.map(\.boundingBox)
//        
//        return (transformedBoxes + textBoxes).reduce(CGRect.null) { $0.union($1) }
//    }
//}
//
//private extension CGRect {
//    func transformed(by transform: CGAffineTransform) -> CGRect {
//        let corners = [
//            origin,
//            CGPoint(x: maxX, y: minY),
//            CGPoint(x: maxX, y: maxY),
//            CGPoint(x: minX, y: maxY)
//        ]
//
//        var out = CGRect.null
//        for point in corners.map({ $0.applying(transform) }) {
//            out = out.union(CGRect(origin: point, size: .zero))
//        }
//        return out
//    }
//}
