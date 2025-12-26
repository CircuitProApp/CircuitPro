//
//  TraceHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct TraceHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>) -> [UUID?: [DrawingPrimitive]] {
        var selectedEdges: [(TraceEdgeComponent, TraceVertexComponent, TraceVertexComponent)] = []
        var maxWidth: CGFloat = 0.0

        for (id, edge) in graph.components(TraceEdgeComponent.self) {
            guard highlightedIDs.contains(id.rawValue),
                  let start = graph.component(TraceVertexComponent.self, for: edge.start),
                  let end = graph.component(TraceVertexComponent.self, for: edge.end) else {
                continue
            }
            selectedEdges.append((edge, start, end))
            maxWidth = max(maxWidth, edge.width)
        }

        guard !selectedEdges.isEmpty else { return [:] }

        let compositePath = CGMutablePath()
        for (_, start, end) in selectedEdges {
            compositePath.move(to: start.point)
            compositePath.addLine(to: end.point)
        }

        let haloPadding: CGFloat = 2.0
        let haloWidth = maxWidth + haloPadding
        let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
        let haloPath = compositePath.copy(strokingWithWidth: haloWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)
        let haloPrimitive = DrawingPrimitive.fill(path: haloPath, color: haloColor)
        return [nil: [haloPrimitive]]
    }
}
