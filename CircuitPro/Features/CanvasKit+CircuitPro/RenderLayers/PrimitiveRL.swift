import AppKit

struct PrimitiveRL: CKView {
    @CKContext var context

    @CKViewBuilder var body: some CKView {
        let primitives = context.items.compactMap { $0 as? AnyCanvasPrimitive }
        let pads = context.items.compactMap { $0 as? Pad }
        let pins = context.items.compactMap { $0 as? Pin }
        let textItems = context.items.compactMap { $0 as? CircuitText.Definition }

        CKGroup {
            for primitive in primitives {
                PrimitiveView(primitive: primitive)
            }

            for pad in pads {
                PadView(pad: pad)
            }

            for pin in pins {
                PinView(pin: pin)
            }

            for text in textItems {
                DefinitionTextView(text: text)
            }
        }
    }
}

private struct PrimitiveView: CKView {
    @CKContext var context
    let primitive: AnyCanvasPrimitive

    @CKViewBuilder var body: some CKView {
        if isLayerVisible(primitive.layerId, layers: context.layers) {
            let color = resolveColor(
                for: primitive,
                in: context,
                fallback: context.environment.canvasTheme.textColor
            )
            let primitives = primitive.makeDrawingPrimitives(with: color)
            if primitives.isEmpty {
                CKEmpty()
            } else {
                var transform = CGAffineTransform(
                    translationX: primitive.position.x,
                    y: primitive.position.y
                )
                .rotated(by: primitive.rotation)
                let worldPrimitives = primitives.map { $0.applying(transform: &transform) }

                let isHighlighted = context.highlightedItemIDs.contains(primitive.id)
                let haloColor = color.applyingOpacity(0.35)
                let haloPath = primitive.makeHaloPath().map { path in
                    path.copy(using: &transform) ?? path
                }

                CKGroup {
                    if isHighlighted, let haloPath {
                        CKPath(path: haloPath).halo(haloColor, width: 5.0)
                    }
                    CKGroup(primitives: worldPrimitives)
                }
            }
        } else {
            CKEmpty()
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
           let layer = context.layers.first(where: { $0.id == layerId }) {
            return layer.color
        }
        return fallback
    }

    private func isLayerVisible(_ layerId: UUID?, layers: [any CanvasLayer]) -> Bool {
        guard let layerId else { return true }
        return layers.first(where: { $0.id == layerId })?.isVisible ?? true
    }
}

private struct PadView: CKView {
    @CKContext var context
    let pad: Pad

    @CKViewBuilder var body: some CKView {
        var transform = CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
            .rotated(by: pad.rotation)
        let path = pad.calculateCompositePath().copy(using: &transform)
            ?? pad.calculateCompositePath()

        let color = padColor(
            layers: context.layers,
            fallback: context.environment.canvasTheme.textColor
        )
        let isHighlighted = context.highlightedItemIDs.contains(pad.id)
        let haloColor = color.applyingOpacity(0.35)

        CKGroup {
            if isHighlighted {
                CKPath(path: path).halo(haloColor, width: 5.0)
            }
            CKPath(path: path).fill(color)
        }
    }

    private func padColor(layers: [any CanvasLayer], fallback: CGColor) -> CGColor {
        if let layer = layers.first(where: { layer in
            guard let pcbLayer = layer as? PCBLayer else { return false }
            return pcbLayer.layerKind == .copper
        }) {
            return layer.color
        }
        return fallback
    }
}

private struct PinView: CKView {
    @CKContext var context
    let pin: Pin

    @CKViewBuilder var body: some CKView {
        let pinColor = context.environment.schematicTheme.pinColor
        let localPrimitives = pin.makeDrawingPrimitives()
            .map { recolor($0, to: pinColor) }
        if localPrimitives.isEmpty {
            CKEmpty()
        } else {
            var transform = CGAffineTransform(translationX: pin.position.x, y: pin.position.y)
                .rotated(by: pin.rotation)
            let worldPrimitives = localPrimitives.map { $0.applying(transform: &transform) }

            let isHighlighted = context.highlightedItemIDs.contains(pin.id)
            let haloColor = pinColor.applyingOpacity(0.35)
            let haloPath = pin.makeHaloPath().map { path in
                path.copy(using: &transform) ?? path
            }

            CKGroup {
                if isHighlighted, let haloPath {
                    CKPath(path: haloPath).halo(haloColor, width: 5.0)
                }
                CKGroup(primitives: worldPrimitives)
            }
        }
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
}

private struct DefinitionTextView: CKView {
    @CKContext var context
    let text: CircuitText.Definition

    @CKViewBuilder var body: some CKView {
        let displayText = resolvedDefinitionText(text)
        if displayText.isEmpty {
            CKEmpty()
        } else {
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
            if path.isEmpty {
                CKEmpty()
            } else {
                let color = text.color.cgColor ?? context.environment.canvasTheme.textColor
                let isHighlighted = context.highlightedItemIDs.contains(text.id)
                let haloColor = color.applyingOpacity(0.35)

                let anchorPoint = CanvasTextGeometry.worldAnchorPosition(
                    anchorPosition: text.anchorPosition,
                    ownerTransform: .identity
                )
                let guidePrimitives = anchorGuidePrimitives(
                    anchorPoint: anchorPoint,
                    textBounds: path.boundingBoxOfPath,
                    context: context,
                    color: color
                )

                CKGroup {
                    if isHighlighted {
                        CKPath(path: path).halo(haloColor, width: 5.0)
                    }
                    CKGroup(primitives: [
                        .fill(path: path, color: color)
                    ] + guidePrimitives)
                }
            }
        }
    }

    private func resolvedDefinitionText(_ text: CircuitText.Definition) -> String {
        if let resolver = context.environment.definitionTextResolver {
            return resolver(text)
        }
        return displayText(for: text.content)
    }

    private func displayText(for content: CircuitTextContent) -> String {
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
}
