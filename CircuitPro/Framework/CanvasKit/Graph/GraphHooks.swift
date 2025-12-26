//
//  GraphHooks.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics

struct GraphHitCandidate {
    let id: NodeID
    let priority: Int
    let area: CGFloat
}

protocol GraphRenderProvider {
    func primitivesByLayer(from graph: CanvasGraph, context: RenderContext) -> [UUID?: [DrawingPrimitive]]
}

protocol GraphHaloProvider {
    func haloPrimitives(from graph: CanvasGraph, context: RenderContext, highlightedIDs: Set<UUID>) -> [UUID?: [DrawingPrimitive]]
}

protocol GraphHitTestProvider {
    func hitTest(point: CGPoint, tolerance: CGFloat, graph: CanvasGraph, context: RenderContext) -> GraphHitCandidate?
    func hitTestAll(in rect: CGRect, graph: CanvasGraph, context: RenderContext) -> [NodeID]
}
