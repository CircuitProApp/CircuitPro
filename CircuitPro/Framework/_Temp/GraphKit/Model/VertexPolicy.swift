//
//  VertexPolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


// VertexPolicy.swift (core)
protocol VertexPolicy {
    // Vertices that should never be removed or merged away (e.g., pins)
    func isProtected(_ v: GraphVertex, state: GraphState) -> Bool
    // Can this isolated vertex be auto-deleted?
    func canCullIsolated(_ v: GraphVertex, state: GraphState) -> Bool
    // Given coincident vertices, pick the survivor
    func preferSurvivor(_ candidates: [GraphVertex], state: GraphState) -> GraphVertex
}
