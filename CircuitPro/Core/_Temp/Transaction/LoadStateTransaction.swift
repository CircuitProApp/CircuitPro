//
//  LoadStateTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

// Replace the entire state and feed a specific epicenter to the ruleset.
// Useful for endDrag, where we want normalization to run on the updated state.
struct LoadStateTransaction: GraphTransaction {
    let newState: GraphState
    let epicenter: Set<UUID>

    mutating func apply(to state: inout GraphState) -> Set<UUID> {
        state = newState
        return epicenter
    }
}
