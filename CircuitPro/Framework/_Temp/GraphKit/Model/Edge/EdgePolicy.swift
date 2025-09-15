//
//  EdgePolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import Foundation

protocol EdgePolicy {
    func propagateMetadata(from oldEdges: [GraphEdge], to newEdge: GraphEdge)
    func propagateMetadata(from oldEdge: GraphEdge, to newEdges: [GraphEdge])
    func shouldPreserveVertex(_ vertex: GraphVertex, connecting edgesInRun: [GraphEdge]) -> Bool

    // NEW
    func layerId(of edge: GraphEdge) -> UUID?
    func incidentLayerSet(of vertex: GraphVertex, state: GraphState) -> Set<UUID>
    func shouldEdgeInteractWithVertex(edge: GraphEdge, vertex: GraphVertex, state: GraphState) -> Bool
    func canMergeVertices(_ a: GraphVertex, _ b: GraphVertex, state: GraphState) -> Bool
}

extension EdgePolicy {
    func propagateMetadata(from oldEdges: [GraphEdge], to newEdge: GraphEdge) {}
    func propagateMetadata(from oldEdge: GraphEdge, to newEdges: [GraphEdge]) {}
    func shouldPreserveVertex(_ vertex: GraphVertex, connecting edgesInRun: [GraphEdge]) -> Bool { false }

    // Defaults: non-layered engines behave as before.
    func layerId(of edge: GraphEdge) -> UUID? { nil }
    func incidentLayerSet(of vertex: GraphVertex, state: GraphState) -> Set<UUID> { [] }

    // If the edge has no layer notion, allow interaction; otherwise require same layer.
    func shouldEdgeInteractWithVertex(edge: GraphEdge, vertex: GraphVertex, state: GraphState) -> Bool {
        guard let lid = layerId(of: edge) else { return true }
        return incidentLayerSet(of: vertex, state: state).contains(lid)
    }

    // Only merge coincident vertices when their layer signatures match and are non-empty.
    func canMergeVertices(_ a: GraphVertex, _ b: GraphVertex, state: GraphState) -> Bool {
        let la = incidentLayerSet(of: a, state: state)
        let lb = incidentLayerSet(of: b, state: state)
        guard !la.isEmpty, !lb.isEmpty else { return false }
        return la == lb
    }
}
