//
//  ComponentInstance+CanvasRenderable.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import AppKit

// MARK: - CanvasRenderable Conformance

extension ComponentInstance: CanvasRenderable {

    var renderBounds: CGRect {
        guard let symbolDef = symbolInstance.definition else { return .null }
        return calculateWorldBounds(for: symbolDef.primitives)
    }

    func primitivesByLayer(in context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var result: [UUID?: [DrawingPrimitive]] = [:]

        guard let symbolDef = symbolInstance.definition else { return result }

        let position = symbolInstance.position
        let rotation = symbolInstance.rotation
        let ownerTransform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        // Symbol primitives
        for primitive in symbolDef.primitives {
            let color = resolveColor(for: primitive, in: context)
            let drawPrimitives = primitive.makeDrawingPrimitives(with: color)
            guard !drawPrimitives.isEmpty else { continue }

            var transform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(ownerTransform)
            let worldPrimitives = drawPrimitives.map { $0.applying(transform: &transform) }
            result[primitive.layerId, default: []].append(contentsOf: worldPrimitives)
        }

        // Pin primitives
        for pinDef in symbolDef.pins {
            let localPrimitives = pinDef.makeDrawingPrimitives()
            guard !localPrimitives.isEmpty else { continue }

            let worldTransform = CGAffineTransform(
                translationX: pinDef.position.x, y: pinDef.position.y
            )
            .concatenating(ownerTransform)
            var transform = worldTransform
            let worldPrimitives = localPrimitives.map { $0.applying(transform: &transform) }
            result[nil, default: []].append(contentsOf: worldPrimitives)
        }

        // Text primitives
        for resolvedText in symbolInstance.resolvedItems {
            guard resolvedText.isVisible else { continue }

            let displayText = generateDisplayString(for: resolvedText)
            guard !displayText.isEmpty else { continue }

            let worldPosition = resolvedText.relativePosition.applying(ownerTransform)
            let worldRotation = rotation + resolvedText.cardinalRotation.radians

            let worldPath = makeTextWorldPath(
                displayText: displayText,
                font: resolvedText.font.nsFont,
                anchor: resolvedText.anchor,
                worldPosition: worldPosition,
                worldRotation: worldRotation
            )
            guard !worldPath.isEmpty else { continue }

            let textPrimitive = DrawingPrimitive.fill(
                path: worldPath,
                color: context.environment.canvasTheme.textColor
            )
            result[nil, default: []].append(textPrimitive)
        }

        return result
    }

    func haloPath() -> CGPath? {
        guard let symbolDef = symbolInstance.definition else { return nil }

        let position = symbolInstance.position
        let rotation = symbolInstance.rotation
        let ownerTransform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        let compositePath = CGMutablePath()

        // Symbol halos
        for primitive in symbolDef.primitives {
            guard let halo = primitive.makeHaloPath() else { continue }
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(ownerTransform)
            compositePath.addPath(halo, transform: primTransform)
        }

        // Pin halos
        for pinDef in symbolDef.pins {
            guard let halo = pinDef.makeHaloPath() else { continue }
            let worldTransform = CGAffineTransform(
                translationX: pinDef.position.x, y: pinDef.position.y
            )
            .concatenating(ownerTransform)
            compositePath.addPath(halo, transform: worldTransform)
        }

        // Text halos
        for resolvedText in symbolInstance.resolvedItems {
            guard resolvedText.isVisible else { continue }
            let displayText = generateDisplayString(for: resolvedText)
            guard !displayText.isEmpty else { continue }

            let worldPosition = resolvedText.relativePosition.applying(ownerTransform)
            let worldRotation = rotation + resolvedText.cardinalRotation.radians
            let worldPath = makeTextWorldPath(
                displayText: displayText,
                font: resolvedText.font.nsFont,
                anchor: resolvedText.anchor,
                worldPosition: worldPosition,
                worldRotation: worldRotation
            )
            if !worldPath.isEmpty {
                compositePath.addPath(worldPath)
            }
        }

        return compositePath.isEmpty ? nil : compositePath
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        guard let symbolDef = symbolInstance.definition else { return false }

        let position = symbolInstance.position
        let rotation = symbolInstance.rotation
        let ownerTransform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        // Quick bounds check
        let bounds = calculateWorldBounds(for: symbolDef.primitives)
        guard !bounds.isNull,
            bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        else {
            return false
        }

        // Check primitives
        let ownerInverse = ownerTransform.inverted()
        let localPoint = point.applying(ownerInverse)

        for primitive in symbolDef.primitives {
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            let primLocal = localPoint.applying(primTransform.inverted())
            if primitive.hitTest(primLocal, tolerance: tolerance) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Private Helpers

    private func calculateWorldBounds(for primitives: [AnyCanvasPrimitive]) -> CGRect {
        let position = symbolInstance.position
        let rotation = symbolInstance.rotation
        let ownerTransform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        var combined = CGRect.null
        for primitive in primitives {
            var box = primitive.boundingBox
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            box = box.applying(primTransform)
            combined = combined.union(box)
        }

        return combined.isNull ? .null : combined.applying(ownerTransform)
    }

    private func resolveColor(for primitive: AnyCanvasPrimitive, in context: RenderContext)
        -> CGColor
    {
        if let overrideColor = primitive.color?.cgColor {
            return overrideColor
        }
        if let layerId = primitive.layerId,
            let layer = context.layers.first(where: { $0.id == layerId })
        {
            return layer.color
        }
        return NSColor.systemBlue.cgColor
    }

    private func generateDisplayString(for resolvedText: CircuitText.Resolved) -> String {
        switch resolvedText.content {
        case .static(let text):
            return text
        case .componentName:
            return definition?.name ?? "???"
        case .componentReferenceDesignator:
            let prefix = definition?.referenceDesignatorPrefix ?? "REF?"
            return prefix + String(referenceDesignatorIndex)
        case .componentProperty(let definitionID, let options):
            guard let prop = displayedProperties.first(where: { $0.id == definitionID }) else {
                return ""
            }
            var parts: [String] = []
            if options.showKey { parts.append(prop.key.label) }
            if options.showValue { parts.append(prop.value.description) }
            if options.showUnit, !prop.unit.description.isEmpty {
                parts.append(prop.unit.description)
            }
            return parts.joined(separator: " ")
        }
    }

    private func makeTextWorldPath(
        displayText: String,
        font: NSFont,
        anchor: TextAnchor,
        worldPosition: CGPoint,
        worldRotation: CGFloat
    ) -> CGPath {
        let untransformedPath = TextUtilities.path(for: displayText, font: font)
        guard !untransformedPath.isEmpty else { return untransformedPath }

        let targetPoint = anchor.point(in: untransformedPath.boundingBoxOfPath)
        let offset = CGVector(dx: -targetPoint.x, dy: -targetPoint.y)
        var localTransform = CGAffineTransform(translationX: offset.dx, y: offset.dy)
        let localPath = untransformedPath.copy(using: &localTransform) ?? untransformedPath

        var worldTransform = CGAffineTransform(translationX: worldPosition.x, y: worldPosition.y)
            .rotated(by: worldRotation)
        return localPath.copy(using: &worldTransform) ?? localPath
    }
}
