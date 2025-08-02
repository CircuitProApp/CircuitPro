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

    var anchoredTexts: [AnchoredTextElement]

    var primitives: [AnyPrimitive] {
        symbol.primitives + symbol.pins.flatMap(\.primitives)
    }

    init(
        id: UUID,
        instance: SymbolInstance,
        symbol: Symbol,
        reference: String,
        properties: [ResolvedProperty]
    ) {
        self.id = id
        self.instance = instance
        self.symbol = symbol
        self.reference = reference
        self.properties = properties
        
        self.anchoredTexts = []
        
        // Initial resolution of all text elements.
        self.resolveAnchoredTexts()
    }
    
    mutating func resolveAnchoredTexts() {
        var updatedTexts: [AnchoredTextElement] = []
        let symbolTransform = self.transform

        // Process definitions from the library symbol
        for definition in symbol.anchoredTextDefinitions {
            let override = instance.anchoredTextOverrides.first { $0.definitionID == definition.id }
            if let override, !override.isVisible { continue }

            let anchorAbsolutePos = definition.relativePosition.applying(symbolTransform)
            let finalRelativePos = override?.relativePositionOverride ?? definition.relativePosition
            let finalAbsolutePos = finalRelativePos.applying(symbolTransform)

            let text = resolveText(for: definition, with: override)

            if var existing = self.anchoredTexts.first(where: { $0.sourceDataID == definition.id }) {
                existing.textElement.position = finalAbsolutePos
                existing.textElement.rotation = self.rotation
                existing.textElement.text = text
                existing.anchorPosition = anchorAbsolutePos
                updatedTexts.append(existing)
            } else {
                let textEl = TextElement(id: UUID(), text: text, position: finalAbsolutePos, rotation: self.rotation, font: definition.font, color: definition.color)
                let newElement = AnchoredTextElement(id: UUID(), textElement: textEl, anchorPosition: anchorAbsolutePos, anchorOwnerID: self.id, sourceDataID: definition.id, isFromDefinition: true)
                updatedTexts.append(newElement)
            }
        }

        // Process ad-hoc texts added only to this instance
        for adHoc in instance.adHocTexts {
            let absolutePos = adHoc.relativePosition.applying(symbolTransform)

            if var existing = self.anchoredTexts.first(where: { $0.sourceDataID == adHoc.id }) {
                existing.textElement.position = absolutePos
                existing.textElement.rotation = self.rotation
                existing.textElement.text = adHoc.text
                existing.anchorPosition = absolutePos
                updatedTexts.append(existing)
            } else {
                let textEl = TextElement(id: UUID(), text: adHoc.text, position: absolutePos, rotation: self.rotation, font: adHoc.font, color: adHoc.color)
                let newElement = AnchoredTextElement(id: UUID(), textElement: textEl, anchorPosition: absolutePos, anchorOwnerID: self.id, sourceDataID: adHoc.id, isFromDefinition: false)
                updatedTexts.append(newElement)
            }
        }
        
        self.anchoredTexts = updatedTexts
    }
    
    private func resolveText(for definition: AnchoredTextDefinition, with override: AnchoredTextOverride?) -> String {
        // Override text always has the highest priority.
        if let overrideText = override?.textOverride {
            return overrideText
        }
        
        switch definition.source {
        case .static(let text):
            return text
                
        case .dynamic(let dynamicProperty):
            switch dynamicProperty {
            case .componentName:
                return self.symbol.name

            case .reference:
                return self.reference
                
            case .property(let definitionID):
                // Find the property that corresponds to the definition we need to display.
                // This now safely checks the `source` enum of the `ResolvedProperty`.
                guard let prop = self.properties.first(where: {
                    if case .definition(let defID) = $0.source {
                        return defID == definitionID
                    }
                    return false
                }) else {
                    return "n/a"
                }
                
                // Use the definition's displayOptions to build the final string.
                var parts: [String] = []
                let options = definition.displayOptions
                
                if options.showKey {
                    parts.append("\(prop.key.label):")
                }
                
                if options.showValue {
                    parts.append(prop.value.description)
                }
                
                if options.showUnit, !prop.unit.symbol.isEmpty {
                    parts.append(prop.unit.symbol)
                }
                
                return parts.joined(separator: " ")
            }
        }
    }
}

// MARK: - Conformance (Equatable, Hashable, etc.)
// These remain unchanged as they correctly operate on the updated `SymbolElement` properties.

extension SymbolElement: Equatable, Hashable {
    static func == (lhs: SymbolElement, rhs: SymbolElement) -> Bool {
        lhs.id == rhs.id &&
        lhs.instance == rhs.instance &&
        lhs.reference == rhs.reference &&
        lhs.properties == rhs.properties
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
            resolveAnchoredTexts()
        }
    }

    var rotation: CGFloat {
        get { instance.rotation }
        set {
            let newInstance = instance.copy()
            newInstance.rotation = newValue
            self.instance = newInstance
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

// MARK: - Drawing & Hit-Testing
// The below code for drawing, hit-testing, and bounding boxes does not need
// to change, as it correctly consumes the `primitives` and `anchoredTexts` arrays
// that are resolved by the logic above.

extension SymbolElement: Drawable {
    func makeBodyParameters() -> [DrawingParameters] {
        var allParameters: [DrawingParameters] = []
        var symbolTransform = self.transform

        // 1. Process primitives and pins (defined in local space).
        let childDrawables = (symbol.primitives as [any Drawable]) + (symbol.pins as [any Drawable])
        for drawable in childDrawables {
            for params in drawable.makeBodyParameters() {
                if let transformedPath = params.path.copy(using: &symbolTransform) {
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
        
        if selectedIDs.contains(self.id) {
            let localHaloPath = CGMutablePath()
            let localDrawables = (symbol.primitives as [any Drawable]) + (symbol.pins as [any Drawable])
            for child in localDrawables {
                if let path = child.makeHaloPath() {
                    localHaloPath.addPath(path)
                }
            }
            var symbolTransform = self.transform
            if let transformedHalo = localHaloPath.copy(using: &symbolTransform) {
                finalPath.addPath(transformedHalo)
            }
            
            for textElement in anchoredTexts {
                if let path = textElement.textElement.makeHaloPath() {
                    finalPath.addPath(path)
                }
            }
            
        } else {
            for textElement in anchoredTexts {
                if let textHaloParams = textElement.makeHaloParameters(selectedIDs: selectedIDs) {
                    finalPath.addPath(textHaloParams.path)
                }
            }
        }
        
        guard !finalPath.isEmpty else { return nil }
        
        return DrawingParameters(
            path: finalPath, lineWidth: 4.0, fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        )
    }
}

extension SymbolElement: Hittable {
    func hitTest(_ worldPoint: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        let localPoint = worldPoint.applying(self.transform.inverted())
        
        for textElement in anchoredTexts {
            if let textHitResult = textElement.hitTest(worldPoint, tolerance: tolerance) {
                let newOwnerPath = [self.id] + textHitResult.ownerPath
                return CanvasHitTarget(
                    partID: textHitResult.partID, ownerPath: newOwnerPath,
                    kind: textHitResult.kind, position: worldPoint
                )
            }
        }
        
        for pin in symbol.pins {
            if let pinHitResult = pin.hitTest(localPoint, tolerance: tolerance) {
                let newOwnerPath = [self.id] + pinHitResult.ownerPath
                return CanvasHitTarget(
                    partID: pinHitResult.partID, ownerPath: newOwnerPath,
                    kind: pinHitResult.kind, position: worldPoint
                )
            }
        }

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
        let textBoxes = anchoredTexts.map(\.boundingBox)
        
        return (transformedBoxes + textBoxes).reduce(CGRect.null) { $0.union($1) }
    }
}

private extension CGRect {
    func transformed(by transform: CGAffineTransform) -> CGRect {
        let corners = [
            origin,
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY)
        ]

        var out = CGRect.null
        for point in corners.map({ $0.applying(transform) }) {
            out = out.union(CGRect(origin: point, size: .zero))
        }
        return out
    }
}
