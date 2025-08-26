//
//  GraphEngine.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI

@Observable
final class GraphEngine {
    var currentState: GraphState
    private let ruleset: GraphRuleset

    var onChange: ((GraphDelta, GraphState) -> Void)?

    init(initialState: GraphState, ruleset: GraphRuleset) {
        self.currentState = initialState
        self.ruleset = ruleset
    }

    @discardableResult
    func execute<T: GraphTransaction>(transaction: inout T) -> GraphDelta {
        let initialState = self.currentState

        var dirtyState = initialState
        let epicenter = transaction.apply(to: &dirtyState)

        let context = ResolutionContext(epicenter: epicenter)
        let finalState = ruleset.resolve(state: dirtyState, context: context)

        let delta = GraphState.computeDelta(from: initialState, to: finalState)
        self.currentState = finalState
        onChange?(delta, finalState)   // notify observers
        return delta
    }
}

// MARK: - Engine utility for non-normalizing state pushes during drag

extension GraphEngine {
    // Push a new state without invoking the ruleset (used by updateDrag)
    func replaceState(_ newState: GraphState) {
        let delta = GraphState.computeDelta(from: currentState, to: newState)
        currentState = newState
        onChange?(delta, newState)
    }
}
