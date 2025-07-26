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

    // --- 1. CHANGE THIS to a stored property ---
    var anchoredTexts: [AnchoredTextElement]

    var primitives: [AnyPrimitive] {
        symbol.primitives + symbol.pins.flatMap(\.primitives)
    }

    // --- 2. ADD AN EXPLICIT INIT ---
    init(id: UUID, instance: SymbolInstance, symbol: Symbol) {
        self.id = id
        self.instance = instance
        self.symbol = symbol
        // Initialize the stored property.
        self.anchoredTexts = []
        // Manually resolve the texts upon creation.
        self.resolveAnchoredTexts()
    }
    
    // --- 3. CREATE A HELPER to resolve texts ---
    private mutating func resolveAnchoredTexts() {
        var resolved: [AnchoredTextElement] = []
        let symbolTransform = self.transform

        // Process definitions from the library symbol
        for definition in symbol.anchoredTextDefinitions {
            let override = instance.anchoredTextOverrides.first { $0.definitionID == definition.id }
            if let override, !override.isVisible { continue }

            let text = override?.textOverride ?? definition.defaultText
            let relativePos = override?.relativePositionOverride ?? definition.relativePosition
            let absolutePos = relativePos.applying(symbolTransform)
            let textEl = TextElement(id: UUID(), text: text, position: absolutePos, rotation: self.rotation, font: definition.font, color: definition.color)

            // The ID is now stable, derived from the data source!
            resolved.append(AnchoredTextElement(id: definition.id, textElement: textEl, anchorPosition: self.position, anchorOwnerID: self.id, sourceDataID: definition.id, isFromDefinition: true))
        }

        // Process ad-hoc texts added only to this instance
        for adHoc in instance.adHocTexts {
            let absolutePos = adHoc.relativePosition.applying(symbolTransform)
            let textEl = TextElement(id: UUID(), text: adHoc.text, position: absolutePos, rotation: self.rotation, font: adHoc.font, color: adHoc.color)
            
            // The ID is now stable, derived from the data source!
            resolved.append(AnchoredTextElement(id: adHoc.id, textElement: textEl, anchorPosition: self.position, anchorOwnerID: self.id, sourceDataID: adHoc.id, isFromDefinition: false))
        }
        self.anchoredTexts = resolved
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
            let newInstance = instance.copy()
            newInstance.position = newValue
            self.instance = newInstance
            // --- 4. UPDATE on change ---
            // After moving, we must re-resolve texts to update their absolute positions.
            resolveAnchoredTexts()
        }
    }

    var rotation: CGFloat {
        get { instance.rotation }
        set {
            let newInstance = instance.copy()
            newInstance.rotation = newValue
            self.instance = newInstance
            // --- 4. UPDATE on change ---
            resolveAnchoredTexts()
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
    func makeBodyParameters() -> [DrawingParameters] {
        var allParameters: [DrawingParameters] = []
        var symbolTransform = self.transform

        // 1. Process primitives and pins (defined in local space).
        let childDrawables = (symbol.primitives as [any Drawable]) + (symbol.pins as [any Drawable])
        for drawable in childDrawables {
            for params in drawable.makeBodyParameters() {
                if let transformedPath = params.path.copy(using: &symbolTransform) {
                    // **FIXED**: Create a new struct instead of calling a non-existent .copy() method.
                    allParameters.append(DrawingParameters(
                        path: transformedPath,
                        lineWidth: params.lineWidth,
                        fillColor: params.fillColor,
                        strokeColor: params.strokeColor,
                        lineDashPattern: params.lineDashPattern,
                        lineCap: params.lineCap,
                        lineJoin: params.lineJoin,
                        fillRule: params.fillRule
                    ))
                }
            }
        }
        
        // 2. Process anchored texts (already in world space).
        for textElement in anchoredTexts {
            allParameters.append(contentsOf: textElement.makeBodyParameters())
        }
        
        return allParameters
    }
    
    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
        let finalPath = CGMutablePath()
        
        // --- 1. Check if the SymbolElement ITSELF is selected ---
        if selectedIDs.contains(self.id) {
            // The whole symbol is selected, so we draw a halo around everything.
            
            // 1.1 Add halos from local-space children (primitives, pins).
            let localHaloPath = CGMutablePath()
            let localDrawables = (symbol.primitives as [any Drawable]) + (symbol.pins as [any Drawable])
            for child in localDrawables {
                if let haloParams = child.makeHaloParameters() { // We can use the old method here
                    localHaloPath.addPath(haloParams.path)
                }
            }
            var symbolTransform = self.transform
            if let transformedHalo = localHaloPath.copy(using: &symbolTransform) {
                finalPath.addPath(transformedHalo)
            }
            
            // 1.2 Add halos from world-space children (text).
            for textElement in anchoredTexts {
                if let haloParams = textElement.textElement.makeHaloParameters() {
                    finalPath.addPath(haloParams.path)
                }
            }
            
        } else {
            // --- 2. The symbol is NOT selected; check for SUB-SELECTED children ---
            // We only need to check children that can be sub-selected, which are our anchored texts.
            for textElement in anchoredTexts {
                // We ask the text element to draw its halo, passing the selection context down.
                // It will only return a path if its ID is in the selectedIDs set.
                if let textHaloParams = textElement.makeHaloParameters(selectedIDs: selectedIDs) {
                    finalPath.addPath(textHaloParams.path)
                }
            }
        }
        
        guard !finalPath.isEmpty else { return nil }
        
        // --- 3. Return the final, combined halo ---
        return DrawingParameters(
            path: finalPath, lineWidth: 4.0, fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        )
    }
}


// MARK: - Hittable and Bounded (Corrected)
extension SymbolElement: Hittable {
    func hitTest(_ worldPoint: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        let localPoint = worldPoint.applying(self.transform.inverted())

        // Note: Hit test order is important. More specific elements should be checked first.
        // Text is often on top of everything, so check it before primitives.
        
        // 1. Check anchored texts first (in world space).
        for textElement in anchoredTexts {
            if let textHitResult = textElement.hitTest(worldPoint, tolerance: tolerance) {
                let newOwnerPath = [self.id] + textHitResult.ownerPath
                return CanvasHitTarget(
                    partID: textHitResult.partID, ownerPath: newOwnerPath,
                    kind: textHitResult.kind, position: worldPoint
                )
            }
        }
        
        // 2. Check pins (in local space).
        for pin in symbol.pins {
            if let pinHitResult = pin.hitTest(localPoint, tolerance: tolerance) {
                let newOwnerPath = [self.id] + pinHitResult.ownerPath
                return CanvasHitTarget(
                    partID: pinHitResult.partID, ownerPath: newOwnerPath,
                    kind: pinHitResult.kind, position: worldPoint
                )
            }
        }

        // 3. Check body primitives (in local space).
        for primitive in symbol.primitives {
            if let primitiveHitResult = primitive.hitTest(localPoint, tolerance: tolerance) {
                let newOwnerPath = [self.id] + primitiveHitResult.ownerPath
                return CanvasHitTarget(
                    partID: primitiveHitResult.partID, ownerPath: newOwnerPath,
                    kind: primitiveHitResult.kind, position: worldPoint
                )
            }
        }
        return nil
    }
}

extension SymbolElement: Bounded {
    var boundingBox: CGRect {
        let transform = self.transform
        let localBoxes = symbol.primitives.map(\.boundingBox) + symbol.pins.map(\.boundingBox)
        let transformedBoxes = localBoxes.map { $0.transformed(by: transform) }

        // 5. ADD THIS: Get the bounding boxes for text (already in world space).
        let textBoxes = anchoredTexts.map(\.boundingBox)
        
        return (transformedBoxes + textBoxes).reduce(CGRect.null) { $0.union($1) }
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
