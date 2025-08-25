//
//  GraphSystem.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/10/25.
//

import Foundation
import SwiftUI

// MARK: - 1. The Form of "Being": The Pure Data State

/// A pure, value-type snapshot of the graph's topology, geometry, and semantic data.
/// This struct has no behavior; it is simply the "source of truth" at a moment in time.
public struct GraphState {
    // --- Topological & Geometric State ---
    // CORRECTED: Properties are now 'var' to allow mutation on a *copy* of the state.
    // The struct itself remains a value type, ensuring state changes are explicit.
    var vertices: [WireVertex.ID: WireVertex]
    var edges: [WireEdge.ID: WireEdge]
    var adjacency: [WireVertex.ID: Set<WireEdge.ID>]

    // --- Semantic State ---
    var netNames: [UUID: String]

    /// Creates an empty graph state.
    static var empty: GraphState {
        GraphState(vertices: [:], edges: [:], adjacency: [:], netNames: [:])
    }

    /// (Phase 3) Computes the difference between this state and a new state.
    static func computeDelta(from oldState: GraphState, to newState: GraphState) -> GraphDelta {
        // TODO: In Phase 3, this will be implemented to provide surgical UI updates.
        return GraphDelta()
    }
}

// MARK: - 2. The Form of "Intent": Transactions & Deltas

/// Represents a minimal description of changes between two `GraphState`s.
/// The UI layer will use this to perform efficient, surgical updates.
public struct GraphDelta {
    // TODO: In Phase 3, this will be populated with data.
}

/// A protocol representing a single, atomic user intention to change the graph.
protocol GraphTransaction {
    /// Applies the initial, direct ("dirty") change to a state.
    /// - Parameter state: The state to be mutated.
    /// - Returns: The set of vertex IDs that were at the epicenter of this change.
    func apply(to state: inout GraphState) -> Set<WireVertex.ID>
}

// MARK: - 3. The Form of "Law": Rulesets

/// A context object passed to a ruleset, providing information about the initial change.
struct ResolutionContext {
    /// The set of vertex IDs that were directly moved or created by the user's transaction.
    let epicenter: Set<WireVertex.ID>
}

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

/// An implementation of `GraphRuleset` for standard orthogonal schematic wires.
struct OrthogonalWireRuleset: GraphRuleset {
    func resolve(state: GraphState, context: ResolutionContext) -> GraphState {
        // For Phase 1, it does nothing and just returns the state.
        return state
    }
}

// MARK: - 4. The Form of "Orchestration": The Engine

/// The central processing engine that manages state transitions.
@Observable
class GraphEngine {
    /// The single source of truth for the current state of the graph.
    private(set) var currentState: GraphState
    private let ruleset: GraphRuleset

    init(initialState: GraphState, ruleset: GraphRuleset) {
        self.currentState = initialState
        self.ruleset = ruleset
    }

    /// The primary method for mutating the graph.
    @discardableResult
    func execute(transaction: GraphTransaction) -> GraphDelta {
        let initialState = self.currentState
        
        var dirtyState = initialState
        let epicenter = transaction.apply(to: &dirtyState)

        let context = ResolutionContext(epicenter: epicenter)
        let finalState = ruleset.resolve(state: dirtyState, context: context)

        let delta = GraphState.computeDelta(from: initialState, to: finalState)
        self.currentState = finalState

        return delta
    }
}
