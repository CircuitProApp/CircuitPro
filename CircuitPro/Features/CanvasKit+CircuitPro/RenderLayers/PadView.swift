import AppKit

struct PadView: CKView {
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
