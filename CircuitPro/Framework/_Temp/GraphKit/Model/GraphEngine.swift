// GraphEngine.swift
import SwiftUI
import CoreGraphics

@Observable
final class GraphEngine {
    var currentState: GraphState
    private let ruleset: GraphRuleset
    let grid: GridPolicy
    private let policy: VertexPolicy?

    var onChange: ((GraphDelta, GraphState) -> Void)?

    init(initialState: GraphState, ruleset: GraphRuleset, grid: GridPolicy, policy: VertexPolicy? = nil) {
        self.currentState = initialState
        self.ruleset = ruleset
        self.grid = grid
        self.policy = policy
    }
    
    @discardableResult
    func execute<T: GraphTransaction>(transaction: inout T) -> GraphDelta {
        let initial = currentState
        var dirty = initial

        let tctx = TransactionContext(grid: grid)
        let epicenter = transaction.apply(to: &dirty, context: tctx)

        // Compute neighborhood for rules
        let aabb = RectUtils.aabb(around: epicenter, in: dirty, padding: grid.step)
        let rctx = ResolutionContext(epicenter: epicenter, grid: grid, neighborhood: aabb, policy: policy)

        let final = ruleset.resolve(state: dirty, context: rctx)

        let delta = GraphState.computeDelta(from: initial, to: final, tol: grid.epsilon)
        currentState = final
        onChange?(delta, final)
        return delta
    }

    func replaceState(_ newState: GraphState) {
        let delta = GraphState.computeDelta(from: currentState, to: newState, tol: grid.epsilon)
        currentState = newState
        onChange?(delta, newState)
    }
}

