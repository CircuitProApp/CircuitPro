// GraphEngine.swift
import SwiftUI
import CoreGraphics

@Observable
final class GraphEngine {
    var currentState: GraphState
    private let ruleset: GraphRuleset
    let geometry: GeometryPolicy
    private let policy: VertexPolicy?
    // --- ADDED: A property to hold the formal EdgePolicy ---
    private let edgePolicy: EdgePolicy?

    var onChange: ((GraphDelta, GraphState) -> Void)?

    // --- MODIFIED: The initializer now accepts the formal EdgePolicy ---
    init(
        initialState: GraphState,
        ruleset: GraphRuleset,
        geometry: GeometryPolicy,
        policy: VertexPolicy? = nil,
        edgePolicy: EdgePolicy? = nil
    ) {
        self.currentState = initialState
        self.ruleset = ruleset
        self.geometry = geometry
        self.policy = policy
        self.edgePolicy = edgePolicy
    }
    
    @discardableResult
    func execute<T: GraphTransaction>(transaction: inout T) -> GraphDelta {
        let initial = currentState
        var dirty = initial

        let tctx = TransactionContext(geometry: geometry)
        let epicenter = transaction.apply(to: &dirty, context: tctx)

        if transaction is MetadataOnlyTransaction {
            let delta = GraphState.computeDelta(from: initial, to: dirty, tol: geometry.epsilon)
            currentState = dirty
            onChange?(delta, dirty)
            return delta
        }

        let aabb = RectUtils.aabb(around: epicenter, in: dirty, padding: geometry.neighborhoodPadding)
        
        // --- MODIFIED: The resolution context is now created with the EdgePolicy ---
        // This makes the policy available to all rules during the resolve phase.
        let rctx = ResolutionContext(
            epicenter: epicenter,
            geometry: geometry,
            neighborhood: aabb,
            policy: policy,
            edgePolicy: edgePolicy
        )

        let final = ruleset.resolve(state: dirty, context: rctx)
        let delta = GraphState.computeDelta(from: initial, to: final, tol: geometry.epsilon)
        currentState = final
        onChange?(delta, final)
        return delta
    }

    func replaceState(_ newState: GraphState) {
        let delta = GraphState.computeDelta(from: currentState, to: newState, tol: geometry.epsilon)
        currentState = newState
        onChange?(delta, newState)
    }
}
