import AppKit

struct GraphFootprintRenderProvider: GraphRenderProvider {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (_, component) in graph.components(GraphFootprintComponent.self) {
            let ownerTransform = component.ownerTransform

            for primitive in component.primitives {
                let resolvedColor = resolveColor(for: primitive, in: context)
                let primitives = primitive.makeDrawingPrimitives(with: resolvedColor)
                guard !primitives.isEmpty else { continue }

                var transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                    .rotated(by: primitive.rotation)
                    .concatenating(ownerTransform)
                let worldPrimitives = primitives.map { $0.applying(transform: &transform) }
                primitivesByLayer[primitive.layerId, default: []].append(contentsOf: worldPrimitives)
            }
        }

        return primitivesByLayer
    }

    private func resolveColor(for primitive: AnyCanvasPrimitive, in context: RenderContext) -> CGColor {
        if let overrideColor = primitive.color?.cgColor {
            return overrideColor
        }
        if let layerId = primitive.layerId,
           let layer = context.layers.first(where: { $0.id == layerId }) {
            return layer.color
        }
        return NSColor.systemBlue.cgColor
    }
}
