// Features/Canvas/RenderLayers/ElementsRenderLayer.swift

import AppKit

/// Renders all canvas items and their selection halos, organizing them into a hierarchy
/// of CALayers that mirrors the `CanvasLayer` data model from the context.
final class ElementsRenderLayer: RenderLayer {

    private var backingLayers: [UUID: CALayer] = [:]
    private var defaultLayer: CALayer?
    private weak var hostLayer: CALayer?

    private struct RenderableItem {
        let id: UUID
        let primitives: [LayeredDrawingPrimitive]
        let haloPath: CGPath?
        let haloColor: CGColor?
        let ownerID: UUID?
    }

    func install(on hostLayer: CALayer) {
        self.hostLayer = hostLayer
    }

    func update(using context: RenderContext) {
        guard let hostLayer = self.hostLayer else { return }

        // 1. Setup the CALayer hierarchy to match the data model.
        reconcileLayers(context: context, hostLayer: hostLayer)

        // 2. Clear all layers completely before redrawing.
        var allLayersToClear: [CALayer] = Array(backingLayers.values)
        if let defaultLayer = self.defaultLayer { allLayersToClear.append(defaultLayer) }
        allLayersToClear.forEach { $0.sublayers?.forEach { $0.removeFromSuperlayer() } }

        // --- 4. GATHER ALL PRIMITIVES FIRST ---

        var bodyPrimitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        var haloPrimitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        let renderables = gatherItemRenderables(from: context.items, context: context)

        for renderable in renderables {
            for layered in renderable.primitives {
                bodyPrimitivesByLayer[layered.layerId, default: []].append(layered.primitive)
            }

            guard let haloPath = renderable.haloPath else { continue }
            let isHighlighted = context.highlightedItemIDs.contains(renderable.id)
                || (renderable.ownerID.map { context.highlightedItemIDs.contains($0) } ?? false)
            guard isHighlighted else { continue }

            let haloColor = (renderable.haloColor ?? NSColor.systemBlue.cgColor)
                .copy(alpha: 0.4) ?? NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            let haloPrimitive = DrawingPrimitive.stroke(
                path: haloPath,
                color: haloColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            let layerTargets = layerTargets(for: renderable.primitives)
            for layerId in layerTargets {
                haloPrimitivesByLayer[layerId, default: []].append(haloPrimitive)
            }
        }

        // Graph-backed halos are disabled for now.

        // --- 5. RENDER EVERYTHING ---

        // Merge the keys from both dictionaries to ensure we visit every layer that has content.
        let allLayerIDs = Set(bodyPrimitivesByLayer.keys).union(haloPrimitivesByLayer.keys)

        for layerID in allLayerIDs {
            let targetLayer: CALayer?
            if let layerID = layerID, let backingLayer = backingLayers[layerID] {
                targetLayer = backingLayer
            } else {
                targetLayer = getOrCreateDefaultLayer(on: hostLayer)
            }

            guard let renderLayer = targetLayer, !renderLayer.isHidden else { continue }

            // --- FIX: RENDER HALOS FIRST ---
            // By rendering halos before bodies, the bodies will be drawn on top,
            // correctly placing the halo "behind" the element.
            if let halos = haloPrimitivesByLayer[layerID] {
                render(primitives: halos, onto: renderLayer)
            }
            if let bodies = bodyPrimitivesByLayer[layerID] {
                render(primitives: bodies, onto: renderLayer)
            }
            // --- END FIX ---
        }
    }

    // MARK: - Primitive Gathering

    private func gatherItemRenderables(
        from items: [any CanvasItem],
        context: RenderContext
    ) -> [RenderableItem] {
        var collected: [RenderableItem] = []

        for item in items {
            if let component = item as? ComponentInstance {
                collected.append(contentsOf: renderables(for: component, context: context))
                continue
            }
            if let primitive = item as? AnyCanvasPrimitive {
                collected.append(renderable(for: primitive, context: context))
                continue
            }
            if let pin = item as? Pin {
                collected.append(renderable(for: pin, context: context))
                continue
            }
            if let pad = item as? Pad {
                collected.append(renderable(for: pad, context: context))
                continue
            }
            if let text = item as? CircuitText.Definition {
                if let renderable = renderable(for: text, context: context) {
                    collected.append(renderable)
                }
                continue
            }
        }

        return collected
    }

    private func renderables(for component: ComponentInstance, context: RenderContext) -> [RenderableItem] {
        let target = context.environment.textTarget

        switch target {
        case .symbol:
            guard let symbolDef = component.symbolInstance.definition else { return [] }
            let ownerTransform = CGAffineTransform(
                translationX: component.symbolInstance.position.x,
                y: component.symbolInstance.position.y
            ).rotated(by: component.symbolInstance.rotation)

            var bodyPrimitives: [LayeredDrawingPrimitive] = []

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
                for worldPrimitive in worldPrimitives {
                    bodyPrimitives.append(LayeredDrawingPrimitive(worldPrimitive, layerId: primitive.layerId))
                }
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
                for worldPrimitive in worldPrimitives {
                    bodyPrimitives.append(LayeredDrawingPrimitive(worldPrimitive, layerId: nil))
                }
            }

            var renderables: [RenderableItem] = []
            let bodyHalo = componentBodyHalo(
                primitives: symbolDef.primitives,
                pins: symbolDef.pins,
                ownerTransform: ownerTransform
            )
            renderables.append(
                RenderableItem(
                    id: component.id,
                    primitives: bodyPrimitives,
                    haloPath: bodyHalo,
                    haloColor: symbolHaloColor(for: context)
                    , ownerID: nil
                )
            )

            let textEntries = componentTextEntries(component, target: .symbol, context: context)
            renderables.append(contentsOf: textEntries)

            return renderables

        case .footprint:
            guard let footprint = component.footprintInstance,
                  case .placed = footprint.placement,
                  let definition = footprint.definition
            else {
                return []
            }

            let ownerTransform = CGAffineTransform(
                translationX: footprint.position.x,
                y: footprint.position.y
            ).rotated(by: footprint.rotation)

            var bodyPrimitives: [LayeredDrawingPrimitive] = []
            let primitives = resolveFootprintPrimitives(
                for: footprint,
                definition: definition,
                context: context
            )

            for primitive in primitives {
                let color = resolveColor(
                    for: primitive,
                    in: context,
                    fallback: NSColor.systemBlue.cgColor
                )
                let drawPrimitives = primitive.makeDrawingPrimitives(with: color)
                guard !drawPrimitives.isEmpty else { continue }

                var transform = CGAffineTransform(
                    translationX: primitive.position.x, y: primitive.position.y
                )
                .rotated(by: primitive.rotation)
                .concatenating(ownerTransform)
                let worldPrimitives = drawPrimitives.map { $0.applying(transform: &transform) }
                for worldPrimitive in worldPrimitives {
                    bodyPrimitives.append(LayeredDrawingPrimitive(worldPrimitive, layerId: primitive.layerId))
                }
            }

            for pad in definition.pads {
                let localPath = pad.calculateCompositePath()
                guard !localPath.isEmpty else { continue }
                let color = NSColor.systemRed.cgColor
                let primitive = DrawingPrimitive.fill(path: localPath, color: color)
                var transform = CGAffineTransform(
                    translationX: pad.position.x, y: pad.position.y
                )
                .rotated(by: pad.rotation)
                .concatenating(ownerTransform)
                let worldPrimitive = primitive.applying(transform: &transform)
                bodyPrimitives.append(LayeredDrawingPrimitive(worldPrimitive, layerId: nil))
            }

            var renderables: [RenderableItem] = []
            let bodyHalo = componentBodyHalo(
                primitives: primitives,
                pads: definition.pads,
                ownerTransform: ownerTransform
            )
            renderables.append(
                RenderableItem(
                    id: component.id,
                    primitives: bodyPrimitives,
                    haloPath: bodyHalo,
                    haloColor: symbolHaloColor(for: context)
                    , ownerID: nil
                )
            )

            let textEntries = componentTextEntries(component, target: .footprint, context: context)
            renderables.append(contentsOf: textEntries)

            return renderables
        }
    }

    private func renderable(for primitive: AnyCanvasPrimitive, context: RenderContext) -> RenderableItem {
        let primitives = primitive.makeDrawingPrimitives(in: context)
        return RenderableItem(
            id: primitive.id,
            primitives: primitives,
            haloPath: primitive.haloPath(),
            haloColor: nil,
            ownerID: nil
        )
    }

    private func renderable(for pin: Pin, context: RenderContext) -> RenderableItem {
        let pinTint = pinColor(for: context)
        let localPrimitives = pin.makeDrawingPrimitives()
            .map { recolor($0, to: pinTint) }
        var transform = CGAffineTransform(translationX: pin.position.x, y: pin.position.y)
        let worldPrimitives = localPrimitives.map { $0.applying(transform: &transform) }
        let layered = worldPrimitives.map { LayeredDrawingPrimitive($0, layerId: nil) }
        let haloPath = pin.makeHaloPath().flatMap { path -> CGPath? in
            var haloTransform = CGAffineTransform(translationX: pin.position.x, y: pin.position.y)
            return path.copy(using: &haloTransform)
        }
        return RenderableItem(
            id: pin.id,
            primitives: layered,
            haloPath: haloPath,
            haloColor: pinTint,
            ownerID: nil
        )
    }

    private func renderable(for pad: Pad, context: RenderContext) -> RenderableItem {
        let localPath = pad.calculateCompositePath()
        let color = NSColor.systemRed.cgColor
        let primitive = DrawingPrimitive.fill(path: localPath, color: color)
        var transform = CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
            .rotated(by: pad.rotation)
        let worldPrimitive = primitive.applying(transform: &transform)
        let layered = [LayeredDrawingPrimitive(worldPrimitive, layerId: nil)]

        let haloPath = pad.calculateShapePath().copy(using: &transform)
        return RenderableItem(
            id: pad.id,
            primitives: layered,
            haloPath: haloPath,
            haloColor: nil,
            ownerID: nil
        )
    }

    private func renderable(
        for text: CircuitText.Definition,
        context: RenderContext
    ) -> RenderableItem? {
        guard text.isVisible else { return nil }
        let displayText = displayText(for: text, context: context)
        guard !displayText.isEmpty else { return nil }

        let path = CanvasTextGeometry.worldPath(
            for: displayText,
            font: text.font.nsFont,
            anchor: text.anchor,
            relativePosition: text.relativePosition,
            anchorPosition: text.anchorPosition,
            textRotation: text.cardinalRotation.radians,
            ownerTransform: .identity,
            ownerRotation: 0
        )
        guard !path.isEmpty else { return nil }

        var primitives: [DrawingPrimitive] = []
        primitives.append(.fill(path: path, color: textColor(for: context)))

        let anchorPoint = CanvasTextGeometry.worldAnchorPosition(
            anchorPosition: text.anchorPosition,
            ownerTransform: .identity
        )
        primitives.append(contentsOf: anchorGuidePrimitives(
            anchorPoint: anchorPoint,
            textBounds: path.boundingBoxOfPath,
            context: context
        ))

        let layered = primitives.map { LayeredDrawingPrimitive($0, layerId: nil) }
        return RenderableItem(
            id: text.id,
            primitives: layered,
            haloPath: path,
            haloColor: textColor(for: context),
            ownerID: nil
        )
    }

    private func componentTextEntries(
        _ component: ComponentInstance,
        target: TextTarget,
        context: RenderContext
    ) -> [RenderableItem] {
        let ownerTransform: CGAffineTransform
        let ownerRotation: CGFloat
        let resolvedItems: [CircuitText.Resolved]

        switch target {
        case .symbol:
            ownerTransform = CGAffineTransform(
                translationX: component.symbolInstance.position.x,
                y: component.symbolInstance.position.y
            ).rotated(by: component.symbolInstance.rotation)
            ownerRotation = component.symbolInstance.rotation
            resolvedItems = component.symbolInstance.resolvedItems
        case .footprint:
            guard let footprint = component.footprintInstance,
                  case .placed = footprint.placement
            else { return [] }
            ownerTransform = CGAffineTransform(
                translationX: footprint.position.x,
                y: footprint.position.y
            ).rotated(by: footprint.rotation)
            ownerRotation = footprint.rotation
            resolvedItems = footprint.resolvedItems
        }

        var renderables: [RenderableItem] = []
        for resolvedText in resolvedItems where resolvedText.isVisible {
            let displayText = component.displayString(for: resolvedText, target: target)
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

            let layered = primitives.map { LayeredDrawingPrimitive($0, layerId: nil) }
            let textID = CanvasTextID.makeID(
                for: resolvedText.source,
                ownerID: component.id,
                fallback: resolvedText.id
            )
            renderables.append(
                RenderableItem(
                    id: textID,
                    primitives: layered,
                    haloPath: path,
                    haloColor: textColor(for: context),
                    ownerID: component.id
                )
            )
        }

        return renderables
    }

    private func componentBodyHalo(
        primitives: [AnyCanvasPrimitive],
        pins: [Pin] = [],
        pads: [Pad] = [],
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

        for pad in pads {
            let halo = pad.calculateShapePath()
            let padTransform = CGAffineTransform(
                translationX: pad.position.x, y: pad.position.y
            )
            .rotated(by: pad.rotation)
            .concatenating(ownerTransform)
            composite.addPath(halo, transform: padTransform)
        }

        return composite.isEmpty ? nil : composite
    }

    private func resolveFootprintPrimitives(
        for instance: FootprintInstance,
        definition: FootprintDefinition,
        context: RenderContext
    ) -> [AnyCanvasPrimitive] {
        guard case .placed(let side) = instance.placement else {
            return definition.primitives
        }

        return definition.primitives.map { primitive in
            var copy = primitive
            guard let genericLayerID = copy.layerId,
                let genericKind = LayerKind.allCases.first(where: { $0.stableId == genericLayerID })
            else {
                return copy
            }

            if let specificLayer = context.layers.first(where: { canvasLayer in
                guard let pcbLayer = canvasLayer as? PCBLayer,
                      let layerKind = pcbLayer.layerKind
                else { return false }
                let kindMatches = layerKind == genericKind
                let sideMatches =
                    (side == .front && pcbLayer.layerSide == .front)
                    || (side == .back && pcbLayer.layerSide == .back)
                return kindMatches && sideMatches
            }) {
                copy.layerId = specificLayer.id
            }

            return copy
        }
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

    private func textColor(for context: RenderContext) -> CGColor {
        switch context.environment.textTarget {
        case .symbol:
            return context.environment.schematicTheme.textColor
        case .footprint:
            return context.environment.canvasTheme.textColor
        }
    }

    private func pinColor(for context: RenderContext) -> CGColor {
        switch context.environment.textTarget {
        case .symbol:
            return context.environment.schematicTheme.pinColor
        case .footprint:
            return NSColor.systemBlue.cgColor
        }
    }

    private func symbolHaloColor(for context: RenderContext) -> CGColor {
        switch context.environment.textTarget {
        case .symbol:
            return context.environment.schematicTheme.symbolColor
        case .footprint:
            return NSColor.systemBlue.cgColor
        }
    }

    private func recolor(_ primitive: DrawingPrimitive, to color: CGColor) -> DrawingPrimitive {
        switch primitive {
        case let .fill(path, _, rule):
            return .fill(path: path, color: color, rule: rule)
        case let .stroke(path, _, lineWidth, lineCap, lineJoin, miterLimit, lineDash):
            return .stroke(
                path: path,
                color: color,
                lineWidth: lineWidth,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                lineDash: lineDash
            )
        }
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

    private func displayText(for text: CircuitText.Definition, context: RenderContext) -> String {
        if let resolver = context.environment.definitionTextResolver {
            return resolver(text)
        }
        return fallbackDisplayText(for: text.content)
    }

    private func fallbackDisplayText(for content: CircuitTextContent) -> String {
        switch content {
        case .static(let value):
            return value
        case .componentName:
            return "Name"
        case .componentReferenceDesignator:
            return "REF?"
        case .componentProperty(_, _):
            return ""
        }
    }

    /// Renders a list of already-transformed primitives onto a target CALayer.
    private func render(primitives: [DrawingPrimitive], onto parentLayer: CALayer) {
        for primitive in primitives {
            let shapeLayer = createShapeLayer(for: primitive)
            parentLayer.addSublayer(shapeLayer)
        }
    }

    // MARK: - Helpers


    private func reconcileLayers(context: RenderContext, hostLayer: CALayer) {
        let currentLayerIds = Set(backingLayers.keys)
        let modelLayerIds = Set(context.layers.map { $0.id })

        for id in currentLayerIds.subtracting(modelLayerIds) {
            backingLayers[id]?.removeFromSuperlayer()
            backingLayers.removeValue(forKey: id)
        }

        for layerModel in context.layers where !currentLayerIds.contains(layerModel.id) {
            let newLayer = CALayer(); newLayer.zPosition = CGFloat(layerModel.zIndex); hostLayer.addSublayer(newLayer); backingLayers[layerModel.id] = newLayer
        }

        for layerModel in context.layers {
            let backingLayer = backingLayers[layerModel.id]; backingLayer?.isHidden = !layerModel.isVisible; backingLayer?.zPosition = CGFloat(layerModel.zIndex)
        }
    }

    private func getOrCreateDefaultLayer(on hostLayer: CALayer) -> CALayer {
        if let defaultLayer = self.defaultLayer { return defaultLayer }
        let newLayer = CALayer(); newLayer.zPosition = -1; hostLayer.addSublayer(newLayer); self.defaultLayer = newLayer; return newLayer
    }

    private func layerTargets(for primitives: [LayeredDrawingPrimitive]) -> [UUID?] {
        let targets = Array(Set(primitives.map { $0.layerId }))
        return targets.isEmpty ? [nil] : targets
    }

    private func createShapeLayer(for primitive: DrawingPrimitive) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer();
        switch primitive {
        case let .fill(path, color, rule):
            shapeLayer.path = path; shapeLayer.fillColor = color; shapeLayer.fillRule = rule; shapeLayer.strokeColor = nil; shapeLayer.lineWidth = 0
        case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash):
            shapeLayer.path = path; shapeLayer.strokeColor = color; shapeLayer.lineWidth = lineWidth; shapeLayer.lineCap = lineCap; shapeLayer.lineJoin = lineJoin; shapeLayer.miterLimit = miterLimit; shapeLayer.lineDashPattern = lineDash; shapeLayer.fillColor = nil
        }
        return shapeLayer
    }

}
