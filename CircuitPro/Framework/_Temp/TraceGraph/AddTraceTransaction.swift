import SwiftUI
import CoreGraphics

struct AddTraceTransaction: GraphTransaction {
    let path: [CGPoint]
    let width: CGFloat
    let layerId: UUID
    
    // --- MODIFIED: Added a way to LOOK UP metadata ---
    let lookupMetadata: (GraphEdge.ID) -> (width: CGFloat, layerId: UUID)?
    let assignMetadata: (GraphEdge.ID, CGFloat, UUID) -> Void

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        guard path.count >= 2 else { return [] }
        
        var epicenter = Set<UUID>()
        var lastVertexID: UUID?
        
        for point in path {
            let currentVertexID = getOrCreateVertex(at: point, state: &state, context: context)
            epicenter.insert(currentVertexID)
            
            if let lastID = lastVertexID {
                if let newEdge = state.addEdge(from: lastID, to: currentVertexID) {
                    // This is for drawing the NEW segment, which is correct.
                    assignMetadata(newEdge.id, width, layerId)
                }
            }
            lastVertexID = currentVertexID
        }
        return epicenter
    }
    
    private func getOrCreateVertex(at point: CGPoint, state: inout GraphState, context: TransactionContext) -> UUID {
        let tol = context.tolerance
        
        if let v = state.findVertex(at: point, tol: tol) {
            return v.id
        }
        
        // --- THIS IS THE METADATA-AWARE SPLIT LOGIC ---
        if let edgeToSplit = state.findEdge(at: point, tol: tol) {
            // 1. Look up the metadata of the edge we are about to destroy.
            let metadata = lookupMetadata(edgeToSplit.id)
            
            // 2. Get original topology info.
            let startID = edgeToSplit.start
            let endID = edgeToSplit.end
            let clusterID = state.vertices[startID]?.clusterID
            
            // 3. Perform the split manually.
            state.removeEdge(edgeToSplit.id)
            let newVertex = state.addVertex(at: point, clusterID: clusterID)
            
            // 4. Create the two new edges.
            if let newEdgeA = state.addEdge(from: startID, to: newVertex.id),
               let newEdgeB = state.addEdge(from: newVertex.id, to: endID) {
                
                // 5. CRITICAL: Propagate the metadata to the new child edges.
                if let md = metadata {
                    assignMetadata(newEdgeA.id, md.width, md.layerId)
                    assignMetadata(newEdgeB.id, md.width, md.layerId)
                }
            }
            
            // 6. Return the ID of the new vertex we created.
            return newVertex.id
        }
        
        // If no vertex and no edge, create a new vertex.
        let v = state.addVertex(at: point)
        return v.id
    }
}
