//
//  OrthogonalWireRuleset.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct OrthogonalWireRuleset: GraphRuleset {
    let rules: [GraphRule]

    init() {
        self.rules = [
            MergeCoincidentRule(),
            SplitAtIntermediateVerticesRule(),
            CollapseCollinearRunsRule(),
            RemoveOrphanFreeVerticesRule(),
            UnifyGroupsRule()
        ]
    }

    func resolve(state: GraphState, context: ResolutionContext) -> GraphState {
        var s = state
        for rule in rules { rule.apply(state: &s, context: context) }
        return s
    }
}
