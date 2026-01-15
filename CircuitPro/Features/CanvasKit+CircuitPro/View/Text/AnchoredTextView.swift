import AppKit

struct AnchoredTextView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let text: CircuitText.Resolved
    let id: UUID
    let isParentHighlighted: Bool
    let display: (CircuitText.Resolved) -> String
    let onUpdate: (CircuitText.Resolved) -> Void
    @CKState private var dragStartPosition: CGPoint?
    @CKState private var dragStartPointer: CGPoint?


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
        context.highlightedItemIDs.contains(id) ||
            context.selectedItemIDs.contains(id) ||
            isParentHighlighted
    }

    var body: some CKView {
        let resolved = text
        let display = display(resolved)
        let localBounds = CKText.localBounds(
            for: display,
            font: resolved.font.nsFont,
            anchor: resolved.anchor
        )
        let hitPath = CGPath(rect: localBounds, transform: nil)

        if resolved.isVisible {
            CKGroup {
                CKText(display, font: resolved.font.nsFont, anchor: resolved.anchor)
                    .position(resolved.relativePosition)
                    .rotation(resolved.cardinalRotation.radians)
                    .fill(textColor)
                    .halo((showHalo ? textColor.copy(alpha: 0.3) : .clear) ?? .clear, width: 5)
                    .hoverable(id)
                    .selectable(id)
                    .onDragGesture { phase in
                        switch phase {
                        case .began:
                            dragStartPosition = resolved.relativePosition
                            dragStartPointer = environment.processedMouseLocation ?? context.mouseLocation
                        case .changed(let delta):
                            guard let startPosition = dragStartPosition,
                                  let startPointer = dragStartPointer
                            else { return }
                            let pointer = delta.processedLocation
                            let dx = pointer.x - startPointer.x
                            let dy = pointer.y - startPointer.y
                            var updated = resolved
                            updated.relativePosition = CGPoint(
                                x: startPosition.x + dx,
                                y: startPosition.y + dy
                            )
                            onUpdate(updated)
                        case .ended:
                            dragStartPosition = nil
                            dragStartPointer = nil
                        }
                    }
                    .contentShape(hitPath)

                if let edge = anchorConnectorEdge(from: resolved.anchorPosition, localBounds: localBounds) {
                    CKLine(from: resolved.anchorPosition, to: edge)
                        .stroke(anchorColor, width: 1.0 / context.magnification)
                        .lineDash([5, 5])
                        .excludeFromPaths()
                }

                CKGroup {
                    CKLine(length: 5, direction: .horizontal)
                    CKLine(length: 5, direction: .vertical)
                }
                .position(resolved.anchorPosition)
                .stroke(anchorColor, width: 1.0 / context.magnification)
                .excludeFromPaths()
            }
        }
    }

    private func anchorConnectorEdge(from anchorPoint: CGPoint, localBounds: CGRect) -> CGPoint? {
        guard !localBounds.isEmpty else { return nil }
        let rotation = text.cardinalRotation.radians
        let position = text.relativePosition

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
