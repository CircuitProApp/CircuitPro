import AppKit

struct FootprintRL: CKView {
    @CKContext var context

    @CKViewBuilder var body: some CKView {
        let components = context.items.compactMap { $0 as? ComponentInstance }
        CKGroup {
            for component in components {
                FootprintView(component: component)
            }
        }
    }
}

struct FootprintView: CKView {
    @CKContext var context
    let component: ComponentInstance

    var body: CKGroup {
        guard let footprint = component.footprintInstance,
              let definition = footprint.definition,
              case .placed(let side) = footprint.placement
        else {
            return CKGroup()
        }

        let ownerTransform = CGAffineTransform(
            translationX: footprint.position.x,
            y: footprint.position.y
        )
        .rotated(by: footprint.rotation)

        let layerSide = layerSide(for: side)
        let renderData = footprintRenderData(
            component: component,
            footprint: footprint,
            definition: definition,
            placement: layerSide,
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
                CKPrimitives { _ in renderData.bodyPrimitives }
            ))
        }

        for entry in renderData.textEntries {
            children.append(AnyCKView(AnchoredTextView(entry: entry)))
        }

        return CKGroup(children)
    }

    private struct PadLayerColor {
        let color: CGColor
        let layerID: UUID?
    }

    private struct FootprintRenderData {
        let bodyPrimitives: [DrawingPrimitive]
        let haloPath: CGPath?
        let haloColor: CGColor
        let isHighlighted: Bool
        let textEntries: [SymbolView.TextEntry]
    }

    private func footprintRenderData(
        component: ComponentInstance,
        footprint: FootprintInstance,
        definition: FootprintDefinition,
        placement: LayerSide,
        ownerTransform: CGAffineTransform
    ) -> FootprintRenderData {
        let resolvedPrimitives = resolveFootprintPrimitives(
            definition.primitives,
            placement: placement,
            layers: context.layers
        )

        var bodyPrimitives: [DrawingPrimitive] = []
        for primitive in resolvedPrimitives {
            guard isLayerVisible(primitive.layerId, layers: context.layers) else { continue }
            let color = resolveColor(
                for: primitive,
                in: context,
                fallback: context.environment.canvasTheme.textColor
            )
            let drawPrimitives = primitive.makeDrawingPrimitives(with: color)
            guard !drawPrimitives.isEmpty else { continue }

            var transform = CGAffineTransform(
                translationX: primitive.position.x,
                y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(ownerTransform)

            let worldPrimitives = drawPrimitives.map { $0.applying(transform: &transform) }
            bodyPrimitives.append(contentsOf: worldPrimitives)
        }

        let padColor = padLayerColor(
            placement: placement,
            layers: context.layers,
            fallback: context.environment.canvasTheme.textColor
        )

        for pad in definition.pads {
            guard isLayerVisible(padColor.layerID, layers: context.layers) else { continue }
            var transform = CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
                .concatenating(ownerTransform)
            let path = pad.calculateCompositePath().copy(using: &transform)
                ?? pad.calculateCompositePath()
            bodyPrimitives.append(
                .fill(path: path, color: padColor.color, rule: .evenOdd)
            )
        }

        let haloPath = componentHalo(
            primitives: resolvedPrimitives,
            pads: definition.pads,
            ownerTransform: ownerTransform
        )
        let haloColor = context.environment.canvasTheme.textColor.applyingOpacity(0.35)
        let isHighlighted = context.highlightedItemIDs.contains(component.id)
        let textEntries = componentTextEntries(
            component,
            footprint: footprint,
            ownerTransform: ownerTransform
        )

        return FootprintRenderData(
            bodyPrimitives: bodyPrimitives,
            haloPath: haloPath,
            haloColor: haloColor,
            isHighlighted: isHighlighted,
            textEntries: textEntries
        )
    }

    private func padLayerColor(
        placement: LayerSide,
        layers: [any CanvasLayer],
        fallback: CGColor
    ) -> PadLayerColor {
        let layer = layers.first { layer in
            guard let pcbLayer = layer as? PCBLayer,
                  pcbLayer.layerKind == .copper
            else { return false }
            return pcbLayer.layerSide == placement
        }
        return PadLayerColor(color: layer?.color ?? fallback, layerID: layer?.id)
    }

    private func resolveFootprintPrimitives(
        _ primitives: [AnyCanvasPrimitive],
        placement: LayerSide,
        layers: [any CanvasLayer]
    ) -> [AnyCanvasPrimitive] {
        let kindByID = Dictionary(uniqueKeysWithValues: LayerKind.allCases.map { ($0.stableId, $0) })

        return primitives.map { primitive in
            var copy = primitive
            guard let layerID = copy.layerId,
                  let kind = kindByID[layerID]
            else { return copy }

            if let resolvedLayer = layers.first(where: { layer in
                guard let pcbLayer = layer as? PCBLayer else { return false }
                return pcbLayer.layerKind == kind && pcbLayer.layerSide == placement
            }) {
                copy.layerId = resolvedLayer.id
            }

            return copy
        }
    }

    private func componentTextEntries(
        _ component: ComponentInstance,
        footprint: FootprintInstance,
        ownerTransform: CGAffineTransform
    ) -> [SymbolView.TextEntry] {
        let ownerRotation = footprint.rotation
        let resolvedItems = footprint.resolvedItems

        var entries: [SymbolView.TextEntry] = []
        for resolvedText in resolvedItems where resolvedText.isVisible {
            let displayText = component.displayString(for: resolvedText, target: .footprint)
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

            let textColor = resolvedText.color.cgColor

            var primitives: [DrawingPrimitive] = []
            primitives.append(.fill(path: path, color: textColor))

            let anchorPoint = CanvasTextGeometry.worldAnchorPosition(
                anchorPosition: resolvedText.anchorPosition,
                ownerTransform: ownerTransform
            )
            primitives.append(contentsOf: anchorGuidePrimitives(
                anchorPoint: anchorPoint,
                textBounds: path.boundingBoxOfPath,
                context: context,
                color: textColor
            ))

            let textID = CanvasTextID.makeID(
                for: resolvedText.source,
                ownerID: component.id,
                fallback: resolvedText.id
            )
            entries.append(
                SymbolView.TextEntry(
                    id: textID,
                    primitives: primitives,
                    haloPath: path,
                    haloColor: textColor,
                    ownerID: component.id
                )
            )
        }

        return entries
    }

    private func componentHalo(
        primitives: [AnyCanvasPrimitive],
        pads: [Pad],
        ownerTransform: CGAffineTransform
    ) -> CGPath? {
        let composite = CGMutablePath()

        for primitive in primitives {
            guard let halo = primitive.makeHaloPath() else { continue }
            let primTransform = CGAffineTransform(
                translationX: primitive.position.x,
                y: primitive.position.y
            )
            .rotated(by: primitive.rotation)
            .concatenating(ownerTransform)
            composite.addPath(halo, transform: primTransform)
        }

        for pad in pads {
            let path = pad.calculateCompositePath()
            var transform = CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
                .concatenating(ownerTransform)
            composite.addPath(path, transform: transform)
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
           let layer = context.layers.first(where: { $0.id == layerId }) {
            return layer.color
        }
        return fallback
    }

    private func isLayerVisible(_ layerId: UUID?, layers: [any CanvasLayer]) -> Bool {
        guard let layerId else { return true }
        return layers.first(where: { $0.id == layerId })?.isVisible ?? true
    }

    private func anchorGuidePrimitives(
        anchorPoint: CGPoint,
        textBounds: CGRect,
        context: RenderContext,
        color: CGColor
    ) -> [DrawingPrimitive] {
        guard !textBounds.isNull else { return [] }

        var guides: [DrawingPrimitive] = []

        if let connector = anchorConnectorPath(anchorPoint: anchorPoint, textBounds: textBounds) {
            let dashLength = 4 / context.magnification
            let gapLength = 2 / context.magnification
            guides.append(
                .stroke(
                    path: connector,
                    color: color,
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
                color: color,
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

    private func layerSide(for side: BoardSide) -> LayerSide {
        switch side {
        case .front:
            return .front
        case .back:
            return .back
        }
    }
}
