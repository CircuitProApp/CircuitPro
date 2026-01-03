//
//  RemoveIsolatedFreeVerticesRule.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct RemoveIsolatedFreeVerticesRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        var seeds = context.epicenter
        for id in context.epicenter { for nid in state.neighbors(of: id) { seeds.insert(nid) } }

        for id in seeds {
            guard let v = state.vertices[id] else { continue }
            let deg = state.adjacency[id]?.count ?? 0
            if deg == 0 {
                if context.policy?.canCullIsolated(v, state: state) ?? false {
                    state.removeVertex(id)
                }
            }
        }
    }
}
