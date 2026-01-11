import AppKit

struct PrimitiveRL: CKView {
    @CKContext var context
    @CanvasItems(Pin.self) var pins

    var body: some CKView {
        let primitives = context.items.compactMap { $0 as? AnyCanvasPrimitive }
        let pads = context.items.compactMap { $0 as? Pad }
        let textItems = context.items.compactMap { $0 as? CircuitText.Definition }

        CKGroup {
            for primitive in primitives {
                PrimitiveView(primitive: primitive)
            }

            for pad in pads {
                PadView(pad: pad)
            }

            for pin in pins {
                PinView(pin: pin.value)
                    .hoverable(pin.id)
                    .selectable(pin.id)
                    .onDragGesture { delta in
                        pin.update { pin in
                            pin.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
            }

            for text in textItems {
                DefinitionTextView(text: text)
            }
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
