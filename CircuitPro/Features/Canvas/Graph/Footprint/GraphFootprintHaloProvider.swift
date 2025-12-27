import AppKit

struct GraphFootprintHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (id, component) in graph.components(GraphFootprintComponent.self) {
            guard highlightedIDs.contains(id.rawValue) else { continue }
            let composite = CGMutablePath()
            if let haloPath = makeHaloPath(for: component) {
                composite.addPath(haloPath)
            }

            for (_, text) in graph.components(GraphTextComponent.self) {
                guard text.ownerID == component.ownerID, text.isVisible else { continue }
                let worldPath = text.worldPath()
                if !worldPath.isEmpty {
                    composite.addPath(worldPath)
                }
            }

            for (_, pad) in graph.components(GraphPadComponent.self) {
                guard pad.ownerID == component.ownerID else { continue }
                guard let haloPath = padHaloPath(for: pad) else { continue }
                var transform = pad.worldTransform
                composite.addPath(haloPath, transform: transform)
            }

            guard !composite.isEmpty else { continue }

            let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            let haloPrimitive = DrawingPrimitive.stroke(
                path: composite,
                color: haloColor,
                lineWidth: 5.0,
                lineCap: .round,
                lineJoin: .round
            )

            primitivesByLayer[nil, default: []].append(haloPrimitive)
        }

        return primitivesByLayer
    }

    private func padHaloPath(for component: GraphPadComponent) -> CGPath? {
        let haloWidth: CGFloat = 1.0
        let shapePath = component.pad.calculateShapePath()
        guard !shapePath.isEmpty else { return nil }
        let thickOutline = shapePath.copy(strokingWithWidth: haloWidth * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return thickOutline.union(shapePath)
    }

    private func makeHaloPath(for component: GraphFootprintComponent) -> CGPath? {
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
