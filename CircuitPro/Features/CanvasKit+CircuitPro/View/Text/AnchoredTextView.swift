import AppKit

struct AnchoredTextView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let text: CanvasItemRef<CircuitText.Definition>


    var textColor: CGColor {
        environment.schematicTheme.textColor
    }

    var anchorColor: CGColor {
        let base = environment.schematicTheme.textColor
        guard let ns = NSColor(cgColor: base) else { return base }
        let rgb = ns.usingColorSpace(.sRGB) ?? ns
        let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let target: NSColor = luminance > 0.5 ? .black : .white
        return rgb.blended(withFraction: 0.6, of: target)?.cgColor ?? base
    }

    var showHalo: Bool {
        context.highlightedItemIDs.contains(text.id) ||
            context.selectedItemIDs.contains(text.id)
    }

    var body: some CKView {
        let definition = text.value
        let display = displayText(
            for: definition,
            resolver: environment.definitionTextResolver
        )
        let localBounds = CKText.localBounds(
            for: display,
            font: definition.font.nsFont,
            anchor: definition.anchor
        )
        let hitPath = CKText.hitRectPath(
            localBounds: localBounds,
            position: definition.relativePosition,
            rotation: definition.cardinalRotation.radians
        )

        CKGroup {
            CKText(display, font: definition.font.nsFont, anchor: definition.anchor)
                .position(definition.relativePosition)
                .rotation(definition.cardinalRotation.radians)
                .halo((showHalo ? textColor.copy(alpha: 0.3) : .clear) ?? .clear, width: 5)
                .contentShape(hitPath)
                .hoverable(text.id)
                .selectable(text.id)
                .onDragGesture { delta in
                    text.update { text in
                        text.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                    }
                }

            if let edge = anchorConnectorEdge(from: definition.anchorPosition, localBounds: localBounds) {
                CKLine(from: definition.anchorPosition, to: edge)
                    .stroke(anchorColor, width: 1.0 / context.magnification)
                    .lineDash([5, 5])
            }

            CKGroup {
                CKLine(length: 5, direction: .horizontal)
                CKLine(length: 5, direction: .vertical)
            }
            .position(definition.anchorPosition)
            .stroke(anchorColor, width: 1.0 / context.magnification)
        }
    }

    private func anchorConnectorEdge(from anchorPoint: CGPoint, localBounds: CGRect) -> CGPoint? {
        guard !localBounds.isEmpty else { return nil }
        let rotation = text.value.cardinalRotation.radians
        let position = text.value.relativePosition

        let inverse = CGAffineTransform(
            translationX: -position.x,
            y: -position.y
        )
        .rotated(by: -rotation)

        let localAnchor = anchorPoint.applying(inverse)
        let center = CGPoint(x: localBounds.midX, y: localBounds.midY)
        let halfWidth = localBounds.width / 2
        let halfHeight = localBounds.height / 2
        guard halfWidth > 0, halfHeight > 0 else { return nil }

        let dx = localAnchor.x - center.x
        let dy = localAnchor.y - center.y
        let absDx = abs(dx)
        let absDy = abs(dy)
        guard absDx > 0 || absDy > 0 else { return nil }

        let localEdge: CGPoint
        if absDx / halfWidth >= absDy / halfHeight {
            let scale = halfWidth / max(absDx, .ulpOfOne)
            localEdge = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
        } else {
            let scale = halfHeight / max(absDy, .ulpOfOne)
            localEdge = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
        }

        let forward = CGAffineTransform(
            translationX: position.x,
            y: position.y
        )
        .rotated(by: rotation)
        return localEdge.applying(forward)
    }

}
