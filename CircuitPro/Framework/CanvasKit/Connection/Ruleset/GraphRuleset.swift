//
//  GraphRuleset.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

/// A protocol that defines a complete "physics engine" for a graph.
/// It encapsulates all the rules, constraints, and normalization logic.
protocol GraphRuleset {
    /// Takes a "dirty" state (after a transaction has been applied) and resolves all
    /// constraints and normalization rules to produce a final, "clean" state.
    /// - Parameters:
    ///   - state: The graph state to be resolved.
    ///   - context: Information about the initial change that triggered the resolution.
    /// - Returns: The new, fully resolved and normalized graph state.
    func resolve(state: GraphState, context: ResolutionContext) -> GraphState
}
