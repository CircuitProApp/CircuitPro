//
//  TraceEdgePolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import Foundation

// A proper, self-documenting struct for our edge metadata.
// It's Hashable so we can use it in Sets to check for differences.
struct TraceEdgeMetadata: Hashable {
    let width: CGFloat
    let layerId: UUID
}

/// The concrete implementation of EdgePolicy for our TraceGraph.
/// It knows how to interact with the `edgeMetadata` dictionary.
class TraceEdgePolicy: EdgePolicy {
    // Weak reference back to the domain model to avoid retain cycles.
    weak var traceGraph: TraceGraph?
    
    init() {}
    
    // --- Implementation for Merging/Collapsing ---
    func propagateMetadata(from oldEdges: [GraphEdge], to newEdge: GraphEdge) {
        guard let traceGraph = traceGraph else { return }
        
        // Find any old edge that actually has metadata
        guard let src = oldEdges.first(where: { traceGraph.edgeMetadata[$0.id] != nil }),
              let oldMetadata = traceGraph.edgeMetadata[src.id] else {
            return
        }

        traceGraph.edgeMetadata[newEdge.id] = oldMetadata

        // Clean up old edges' metadata
        for edge in oldEdges {
            traceGraph.edgeMetadata.removeValue(forKey: edge.id)
        }
    }

    // --- Implementation for Splitting ---
    func propagateMetadata(from oldEdge: GraphEdge, to newEdges: [GraphEdge]) {
        guard let traceGraph = traceGraph,
              let oldMetadata = traceGraph.edgeMetadata[oldEdge.id] else {
            return
        }
        
        // When an edge is split, all new segments inherit its properties.
        for newEdge in newEdges {
            traceGraph.edgeMetadata[newEdge.id] = oldMetadata
        }
        
        // Clean up metadata for the old edge that was just destroyed.
        traceGraph.edgeMetadata.removeValue(forKey: oldEdge.id)
    }
    
    // --- Implementation for Preserving Metadata "Seams" ---
    func shouldPreserveVertex(_ vertex: GraphVertex, connecting edgesInRun: [GraphEdge]) -> Bool {
        guard let traceGraph = traceGraph else { return false }

        // Get the metadata for every connected edge.
        let metadataTuples = edgesInRun.compactMap { traceGraph.edgeMetadata[$0.id] }
        
        // Put them in a Set to find the number of unique metadata styles.
        let uniqueMetadata = Set(metadataTuples)
        
        // If there's more than one unique style, this vertex is a critical seam and must be preserved.
        return uniqueMetadata.count > 1
    }
    
    func layerId(of edge: GraphEdge) -> UUID? {
        traceGraph?.edgeMetadata[edge.id]?.layerId
    }

    func incidentLayerSet(of vertex: GraphVertex, state: GraphState) -> Set<UUID> {
        guard let tg = traceGraph else { return [] }
        var layers: Set<UUID> = []
        for eid in state.adjacency[vertex.id] ?? [] {
            if let lid = tg.edgeMetadata[eid]?.layerId {
                layers.insert(lid)
            }
        }
        return layers
    }
}
