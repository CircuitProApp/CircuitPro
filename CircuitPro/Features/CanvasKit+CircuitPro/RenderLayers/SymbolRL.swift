import AppKit

struct SymbolRL: CKView {
    @CKContext var context

    var body: some CKView {
        let components = context.items.compactMap { $0 as? ComponentInstance }
        CKGroup {
            for component in components {
                SymbolView(component: component)
            }
        }
    }
}

struct SymbolView: CKView {
    @CKContext var context
    let component: ComponentInstance

    var body: CKGroup {
        guard let symbolDef = component.symbolInstance.definition else {
            return CKGroup()
        }

        let ownerTransform = CGAffineTransform(
            translationX: component.symbolInstance.position.x,
            y: component.symbolInstance.position.y
        )
        .rotated(by: component.symbolInstance.rotation)

        let renderData = symbolRenderData(
            component: component,
            symbolDef: symbolDef,
            ownerTransform: ownerTransform
        )

        var children: [AnyCKView] = []
        if renderData.isHighlighted, let haloPath = renderData.haloPath {
            children.append(AnyCKView(
                CKPath(path: haloPath).halo(renderData.haloColor, width: 5.0)
            ))
        }

        if !renderData.bodyPrimitives.isEmpty {
            children.append(AnyCKView(
                CKGroup(primitives: renderData.bodyPrimitives)
            ))
        }

        for entry in renderData.textEntries {
            children.append(AnyCKView(AnchoredTextView(entry: entry)))
        }

        return CKGroup(children)
    }

    private struct SymbolRenderData {
        let bodyPrimitives: [DrawingPrimitive]
        let haloPath: CGPath?
        let haloColor: CGColor
        let isHighlighted: Bool
        let textEntries: [TextEntry]
    }

    private func symbolRenderData(
        component: ComponentInstance,
        symbolDef: SymbolDefinition,
        ownerTransform: CGAffineTransform
    ) -> SymbolRenderData {
        var bodyPrimitives: [DrawingPrimitive] = []

        for primitive in symbolDef.primitives {
            let color = resolveColor(
                for: primitive,
                in: context,
                fallback: context.environment.schematicTheme.symbolColor
            )
            let drawPrimitives = primitive.makeDrawingPrimitives(with: color)
            guard !drawPrimitives.isEmpty else { continue }

            var transform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(ownerTransform)
            let worldPrimitives = drawPrimitives.map { $0.applying(transform: &transform) }
            bodyPrimitives.append(contentsOf: worldPrimitives)
        }

        for pin in symbolDef.pins {
            let pinColor = context.environment.schematicTheme.pinColor
            let localPrimitives = pin.makeDrawingPrimitives()
                .map { recolor($0, to: pinColor) }
            guard !localPrimitives.isEmpty else { continue }
            var transform = CGAffineTransform(
                translationX: pin.position.x, y: pin.position.y
            )
            .concatenating(ownerTransform)
            let worldPrimitives = localPrimitives.map { $0.applying(transform: &transform) }
            bodyPrimitives.append(contentsOf: worldPrimitives)
        }

        let haloPath = componentBodyHalo(
            primitives: symbolDef.primitives,
            pins: symbolDef.pins,
            ownerTransform: ownerTransform
        )
        let isHighlighted = context.highlightedItemIDs.contains(component.id)
        let haloColor = context.environment.schematicTheme.symbolColor.applyingOpacity(0.4)
        let textEntries = componentTextEntries(component, context: context)

        return SymbolRenderData(
            bodyPrimitives: bodyPrimitives,
            haloPath: haloPath,
            haloColor: haloColor,
            isHighlighted: isHighlighted,
            textEntries: textEntries
        )
    }

    struct TextEntry {
        let id: UUID
        let primitives: [DrawingPrimitive]
        let haloPath: CGPath?
        let haloColor: CGColor?
        let ownerID: UUID?
    }

    private func componentTextEntries(
        _ component: ComponentInstance,
        context: RenderContext
    ) -> [TextEntry] {
        let ownerTransform = CGAffineTransform(
            translationX: component.symbolInstance.position.x,
            y: component.symbolInstance.position.y
        )
        .rotated(by: component.symbolInstance.rotation)
        let ownerRotation = component.symbolInstance.rotation
        let resolvedItems = component.symbolInstance.resolvedItems

        var entries: [TextEntry] = []
        for resolvedText in resolvedItems where resolvedText.isVisible {
            let displayText = component.displayString(for: resolvedText, target: .symbol)
            guard !displayText.isEmpty else { continue }

            let path = CanvasTextGeometry.worldPath(
                for: displayText,
                font: resolvedText.font.nsFont,
                anchor: resolvedText.anchor,
                relativePosition: resolvedText.relativePosition,
                anchorPosition: resolvedText.anchorPosition,
                textRotation: resolvedText.cardinalRotation.radians,
                ownerTransform: ownerTransform,
                ownerRotation: ownerRotation
            )
            guard !path.isEmpty else { continue }

            var primitives: [DrawingPrimitive] = []
            primitives.append(.fill(path: path, color: textColor(for: context)))

            let anchorPoint = CanvasTextGeometry.worldAnchorPosition(
                anchorPosition: resolvedText.anchorPosition,
                ownerTransform: ownerTransform
            )
            primitives.append(contentsOf: anchorGuidePrimitives(
                anchorPoint: anchorPoint,
                textBounds: path.boundingBoxOfPath,
                context: context
            ))

            let textID = CanvasTextID.makeID(
                for: resolvedText.source,
                ownerID: component.id,
                fallback: resolvedText.id
            )
            entries.append(
                TextEntry(
                    id: textID,
                    primitives: primitives,
                    haloPath: path,
                    haloColor: textColor(for: context),
                    ownerID: component.id
                )
            )
        }

        return entries
    }

    private func componentBodyHalo(
        primitives: [AnyCanvasPrimitive],
        pins: [Pin] = [],
        ownerTransform: CGAffineTransform
    ) -> CGPath? {
        let composite = CGMutablePath()

        for primitive in primitives {
            guard let halo = primitive.makeHaloPath() else { continue }
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x, y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(ownerTransform)
            composite.addPath(halo, transform: primTransform)
        }

        for pin in pins {
            guard let halo = pin.makeHaloPath() else { continue }
            let pinTransform = CGAffineTransform(
                translationX: pin.position.x, y: pin.position.y
            )
            .concatenating(ownerTransform)
            composite.addPath(halo, transform: pinTransform)
        }

        return composite.isEmpty ? nil : composite
    }

    private func resolveColor(
        for primitive: AnyCanvasPrimitive,
        in context: RenderContext,
        fallback: CGColor
    ) -> CGColor {
        if let overrideColor = primitive.color?.cgColor {
            return overrideColor
        }
        if let layerId = primitive.layerId,
            let layer = context.layers.first(where: { $0.id == layerId })
        {
            return layer.color
        }
        return fallback
    }

    private func recolor(_ primitive: DrawingPrimitive, to color: CGColor) -> DrawingPrimitive {
        switch primitive {
        case let .fill(path, _, rule, clipPath):
            return .fill(path: path, color: color, rule: rule, clipPath: clipPath)
        case let .stroke(path, _, lineWidth, lineCap, lineJoin, miterLimit, lineDash, clipPath):
            return .stroke(
                path: path,
                color: color,
                lineWidth: lineWidth,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                lineDash: lineDash,
                clipPath: clipPath
            )
        }
    }

    private func textColor(for context: RenderContext) -> CGColor {
        context.environment.schematicTheme.textColor
    }

    private func anchorGuidePrimitives(
        anchorPoint: CGPoint,
        textBounds: CGRect,
        context: RenderContext
    ) -> [DrawingPrimitive] {
        guard !textBounds.isNull else { return [] }

        var guides: [DrawingPrimitive] = []

        let guideColor = anchorGuideColor(for: context)
        if let connector = anchorConnectorPath(anchorPoint: anchorPoint, textBounds: textBounds) {
            let dashLength = 4 / context.magnification
            let gapLength = 2 / context.magnification
            guides.append(
                .stroke(
                    path: connector,
                    color: guideColor,
                    lineWidth: 1 / context.magnification,
                    lineCap: .round,
                    lineJoin: .round,
                    lineDash: [NSNumber(value: dashLength), NSNumber(value: gapLength)]
                )
            )
        }

        let s: CGFloat = 4 / context.magnification
        let cross = CGMutablePath()
        cross.move(to: CGPoint(x: anchorPoint.x - s, y: anchorPoint.y))
        cross.addLine(to: CGPoint(x: anchorPoint.x + s, y: anchorPoint.y))
        cross.move(to: CGPoint(x: anchorPoint.x, y: anchorPoint.y - s))
        cross.addLine(to: CGPoint(x: anchorPoint.x, y: anchorPoint.y + s))

        guides.append(
            .stroke(
                path: cross,
                color: guideColor,
                lineWidth: 1 / context.magnification
            )
        )

        return guides
    }

    private func anchorConnectorPath(anchorPoint: CGPoint, textBounds: CGRect) -> CGPath? {
        guard !textBounds.isEmpty else { return nil }
        let center = CGPoint(x: textBounds.midX, y: textBounds.midY)
        let halfWidth = textBounds.width / 2
        let halfHeight = textBounds.height / 2
        guard halfWidth > 0, halfHeight > 0 else { return nil }

        let dx = anchorPoint.x - center.x
        let dy = anchorPoint.y - center.y
        let absDx = abs(dx)
        let absDy = abs(dy)
        guard absDx > 0 || absDy > 0 else { return nil }

        let edgePoint: CGPoint
        if absDx / halfWidth >= absDy / halfHeight {
            let scale = halfWidth / max(absDx, .ulpOfOne)
            edgePoint = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
        } else {
            let scale = halfHeight / max(absDy, .ulpOfOne)
            edgePoint = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
        }

        let path = CGMutablePath()
        path.move(to: anchorPoint)
        path.addLine(to: edgePoint)
        return path
    }

    private func anchorGuideColor(for context: RenderContext) -> CGColor {
        let base = textColor(for: context)
        guard let nsColor = NSColor(cgColor: base) else {
            return base
        }
        let blended = nsColor.blended(withFraction: 0.6, of: .black) ?? nsColor
        return blended.withAlphaComponent(0.7).cgColor
    }
}

struct AnchoredTextView: CKView {
    @CKContext var context
    let entry: SymbolView.TextEntry

    @CKViewBuilder var body: some CKView {
        let isHighlighted =
            context.highlightedItemIDs.contains(entry.id)
            || (entry.ownerID.map { context.highlightedItemIDs.contains($0) } ?? false)

        CKGroup {
            if isHighlighted, let haloPath = entry.haloPath {
                let color = (entry.haloColor ?? context.environment.schematicTheme.textColor)
                    .applyingOpacity(0.4)
                CKPath(path: haloPath).halo(color, width: 5.0)
            }

            if !entry.primitives.isEmpty {
                CKGroup(primitives: entry.primitives)
            }
        }
    }
}
