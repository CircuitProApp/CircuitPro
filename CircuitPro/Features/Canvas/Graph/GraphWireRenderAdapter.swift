//
//  GraphWireRenderAdapter.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import AppKit

struct GraphWireRenderAdapter {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?:
        [DrawingPrimitive]]
    {
        var primitivesByLayer: [UUID?: [DrawingPrimitive]] = [:]
        var adjacency: [NodeID: Int] = [:]

        for (_, edge) in graph.components(WireEdgeComponent.self) {
            guard let start = graph.component(WireVertexComponent.self, for: edge.start),
                let end = graph.component(WireVertexComponent.self, for: edge.end)
            else {
                continue
            }

            adjacency[edge.start, default: 0] += 1
            adjacency[edge.end, default: 0] += 1

            let path = CGMutablePath()
            path.move(to: start.point)
            path.addLine(to: end.point)

            let primitive = DrawingPrimitive.stroke(
                path: path,
                color: NSColor.controlAccentColor.cgColor,
                lineWidth: 1.0,
                lineCap: .round
            )
            primitivesByLayer[nil, default: []].append(primitive)
        }

        for (id, vertex) in graph.components(WireVertexComponent.self) {
            let degree = adjacency[id] ?? 0

            // For regular vertices: draw dot when 3+ wires meet (T-junction or more)
            // For pin vertices: draw dot when 2+ wires connect to the pin
            let needsDot: Bool
            if case .pin = vertex.ownership {
                needsDot = degree > 1
            } else {
                needsDot = degree > 2
            }

            guard needsDot else { continue }

            let dotRect = CGRect(x: vertex.point.x - 2, y: vertex.point.y - 2, width: 4, height: 4)
            let dotPath = CGPath(ellipseIn: dotRect, transform: nil)
            let dotPrimitive = DrawingPrimitive.fill(
                path: dotPath, color: NSColor.controlAccentColor.cgColor)
            primitivesByLayer[nil, default: []].append(dotPrimitive)
        }

        return primitivesByLayer
    }
}

extension GraphWireRenderAdapter: GraphRenderProvider {}
