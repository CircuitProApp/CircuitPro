// GraphEngine.swift
import SwiftUI
import CoreGraphics

@Observable
final class GraphEngine {
    var currentState: GraphState
    private let ruleset: GraphRuleset
    let grid: GridPolicy

    var onChange: ((GraphDelta, GraphState) -> Void)?

    init(initialState: GraphState, ruleset: GraphRuleset, grid: GridPolicy) {
        self.currentState = initialState
        self.ruleset = ruleset
        self.grid = grid
    }

    @discardableResult
    func execute<T: GraphTransaction>(transaction: inout T) -> GraphDelta {
        let initial = currentState
        var dirty = initial
        let epicenter = transaction.apply(to: &dirty)

        // Skip resolve for metadata-only edits
        if transaction is MetadataOnlyTransaction {
            let delta = GraphState.computeDelta(from: initial, to: dirty)
            currentState = dirty
            onChange?(delta, dirty)
            return delta
        }

        // Compute neighborhood AABB around epicenter (pad by one grid step)
        let aabb = RectUtils.aabb(around: epicenter, in: dirty, padding: grid.step)
        let ctx = ResolutionContext(epicenter: epicenter, grid: grid, neighborhood: aabb)

        let final = ruleset.resolve(state: dirty, context: ctx)

        let delta = GraphState.computeDelta(from: initial, to: final)
        currentState = final
        onChange?(delta, final)
        return delta
    }
}

extension GraphEngine {
    func replaceState(_ newState: GraphState) {
        let delta = GraphState.computeDelta(from: currentState, to: newState)
        currentState = newState
        onChange?(delta, newState)
    }
}
