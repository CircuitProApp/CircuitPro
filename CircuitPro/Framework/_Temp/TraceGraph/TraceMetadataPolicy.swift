import Foundation

class TraceMetadataPolicy: GraphMetadataPolicy {
    weak var traceGraph: TraceGraph?
    
    init() {}
    
    func propagateMetadata(from oldEdges: [GraphEdge], to newEdge: GraphEdge) {
        guard let firstOldEdge = oldEdges.first,
              let oldMetadata = traceGraph?.traceData[firstOldEdge.id] else {
            return
        }
        
        traceGraph?.traceData[newEdge.id] = oldMetadata
        
        for edge in oldEdges {
            traceGraph?.traceData.removeValue(forKey: edge.id)
        }
    }

    // --- ADDED IMPLEMENTATION ---
    func propagateMetadata(from oldEdge: GraphEdge, to newEdgeA: GraphEdge, and newEdgeB: GraphEdge) {
        // Find the metadata from the original edge that was split.
        guard let oldMetadata = traceGraph?.traceData[oldEdge.id] else {
            return
        }
        
        // Business logic: When an edge is split, both new segments
        // should inherit the same properties (width, layer).
        traceGraph?.traceData[newEdgeA.id] = oldMetadata
        traceGraph?.traceData[newEdgeB.id] = oldMetadata
        
        // Clean up the metadata for the now-deleted original edge.
        traceGraph?.traceData.removeValue(forKey: oldEdge.id)
    }
}
