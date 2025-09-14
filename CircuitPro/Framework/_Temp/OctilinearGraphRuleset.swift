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
            // Note: The existing CollapseLinearRunsRule will only collapse purely
            // horizontal and vertical segments. A more advanced version would be
            // needed to collapse collinear diagonal segments.
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
