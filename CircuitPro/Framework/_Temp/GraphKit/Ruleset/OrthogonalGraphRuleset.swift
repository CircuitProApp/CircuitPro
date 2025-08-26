//
//  OrthogonalGraphRuleset.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct OrthogonalGraphRuleset: GraphRuleset {
    let rules: [GraphRule]

    init() {
        self.rules = [
            MergeCoincidentRule(),
            SplitEdgesAtPassingVerticesRule(),
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
