//
//  GraphTextRenderProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct GraphTextRenderProvider: GraphRenderProvider {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?: [DrawingPrimitive]] {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]

        for (_, component) in graph.components(GraphTextComponent.self) {
            guard component.isVisible else { continue }
            let worldPath = component.worldPath()
            guard !worldPath.isEmpty else { continue }

            let textPrimitive = DrawingPrimitive.fill(
                path: worldPath,
                color: component.color
            )
            primitivesByLayer[component.layerId, default: []].append(textPrimitive)

            if component.showsAnchorGuides {
                let guides = makeAnchorGuides(for: component, textBounds: worldPath.boundingBoxOfPath)
                primitivesByLayer[component.layerId, default: []].append(contentsOf: guides)
            }
        }

        return primitivesByLayer
    }

    private func makeAnchorGuides(for component: GraphTextComponent, textBounds: CGRect) -> [DrawingPrimitive] {
        let adornmentColor = NSColor.systemGray.withAlphaComponent(0.8).cgColor
        var primitives: [DrawingPrimitive] = []

        let crosshairPath = makeCrosshairPath(at: component.worldAnchorPosition)
        primitives.append(.stroke(path: crosshairPath, color: adornmentColor, lineWidth: 0.5))

        if let connectorPath = makeConnectorPath(from: component.worldAnchorPosition, textBounds: textBounds) {
            primitives.append(.stroke(path: connectorPath, color: adornmentColor, lineWidth: 0.5, lineDash: [2, 2]))
        }

        return primitives
    }

    private func makeCrosshairPath(at center: CGPoint, size: CGFloat = 8.0) -> CGPath {
        let halfSize = size / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x - halfSize, y: center.y))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
        return path
    }

    private func makeConnectorPath(from anchorPosition: CGPoint, textBounds: CGRect) -> CGPath? {
        guard !textBounds.isNull else { return nil }
        let connectionPoint = determineConnectionPoint(on: textBounds, towards: anchorPosition)

        let path = CGMutablePath()
        path.move(to: anchorPosition)
        path.addLine(to: connectionPoint)
        return path
    }

    private func determineConnectionPoint(on rect: CGRect, towards point: CGPoint) -> CGPoint {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY

        let absDx = abs(dx)
        let absDy = abs(dy)

        if absDx * rect.height > absDy * rect.width {
            return dx > 0 ? CGPoint(x: rect.maxX, y: rect.midY) : CGPoint(x: rect.minX, y: rect.midY)
        }
        return dy > 0 ? CGPoint(x: rect.midX, y: rect.maxY) : CGPoint(x: rect.midX, y: rect.minY)
    }
}
