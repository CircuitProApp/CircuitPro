//
//  GraphRule.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

protocol GraphRule {
    // Mutates only within its intended neighborhood
    func apply(state: inout GraphState, context: ResolutionContext)
}
