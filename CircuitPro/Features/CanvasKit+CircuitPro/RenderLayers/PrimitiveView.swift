import AppKit

struct PrimitiveView: CKView {
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
