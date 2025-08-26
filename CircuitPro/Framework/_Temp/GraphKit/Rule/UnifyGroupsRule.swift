//
//  UnifyGroupsRule.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


import Foundation

struct UnifyGroupsRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        var visited: Set<UUID> = []

        for seed in context.epicenter {
            guard !visited.contains(seed), state.vertices[seed] != nil else { continue }
            let comp = state.component(from: seed)
            visited.formUnion(comp.vertices)

            // If the component has no edges, clear netIDs
            if comp.edges.isEmpty {
                for v in comp.vertices { state.vertices[v]?.groupID = nil }
                continue
            }

            // Prefer an existing named net if you store names; for now first non-nil groupID or new
            let existing = comp.vertices.compactMap { state.vertices[$0]?.groupID }.first
            let finalID = existing ?? UUID()
            for v in comp.vertices { state.vertices[v]?.groupID = finalID }
        }
    }
}
