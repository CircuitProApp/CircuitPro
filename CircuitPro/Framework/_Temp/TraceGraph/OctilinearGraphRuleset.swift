//
//  OctilinearGraphRuleset.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import Foundation

struct OctilinearGraphRuleset: GraphRuleset {
    let rules: [GraphRule]

    init() {
        // For a basic octilinear router, many of the same cleanup rules apply.
        // We can reuse them directly.
        self.rules = [
            MergeCoincidentRule(),
            SplitEdgesAtPassingVerticesRule(),
            
            // --- THIS IS THE FIX ---
            // This rule is too aggressive. It merges collinear edges into a new edge,
            // but it doesn't know how to transfer the domain-specific `traceData`
            // (width, layerId) to the new edge. Disabling it prevents traces
            // from disappearing when you extend them.
            CollapseLinearRunsRule(),
            
            RemoveIsolatedFreeVerticesRule(),
            AssignClusterIDsRule()
        ]
    }

    func resolve(state: GraphState, context: ResolutionContext) -> GraphState {
        var s = state
        for rule in rules { rule.apply(state: &s, context: context) }
        return s
    }
}
