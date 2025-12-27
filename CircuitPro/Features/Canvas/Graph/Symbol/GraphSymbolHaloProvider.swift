import AppKit

struct GraphSymbolHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (id, component) in graph.components(GraphSymbolComponent.self) {
            guard highlightedIDs.contains(id.rawValue) else { continue }
            guard let haloPath = makeHaloPath(for: component) else { continue }

            let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            let haloPrimitive = DrawingPrimitive.stroke(
                path: haloPath,
                color: haloColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            primitivesByLayer[nil, default: []].append(haloPrimitive)
        }

        return primitivesByLayer
    }

    private func makeHaloPath(for component: GraphSymbolComponent) -> CGPath? {
        let compositePath = CGMutablePath()
        let ownerTransform = component.ownerTransform

        for primitive in component.primitives {
            guard let halo = primitive.makeHaloPath() else { continue }
            let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
                .concatenating(ownerTransform)
            compositePath.addPath(halo, transform: transform)
        }

        return compositePath.isEmpty ? nil : compositePath
    }
}
