//
//  TraceHaloProvider.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

struct TraceHaloProvider: GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<GraphElementID>) -> [UUID?: [DrawingPrimitive]] {
        var selectedEdges: [TraceEdgeComponent] = []
        var maxWidth: CGFloat = 0.0

        for (edgeID, edge) in graph.edgeComponents(TraceEdgeComponent.self) {
            guard highlightedIDs.contains(.edge(edgeID)) else { continue }
            selectedEdges.append(edge)
            maxWidth = max(maxWidth, edge.width)
        }

        guard !selectedEdges.isEmpty else { return [:] }

        let compositePath = CGMutablePath()
        for edge in selectedEdges {
            compositePath.move(to: edge.startPoint)
            compositePath.addLine(to: edge.endPoint)
        }

        let haloPadding: CGFloat = 2.0
        let haloWidth = maxWidth + haloPadding
        let haloColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
        let haloPath = compositePath.copy(strokingWithWidth: haloWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)
        let haloPrimitive = DrawingPrimitive.fill(path: haloPath, color: haloColor)
        return [nil: [haloPrimitive]]
    }
}
