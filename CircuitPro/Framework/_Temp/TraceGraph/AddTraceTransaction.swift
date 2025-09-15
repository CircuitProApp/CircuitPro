import SwiftUI
import CoreGraphics

struct AddTraceTransaction: GraphTransaction {
    let path: [CGPoint]
    let width: CGFloat
    let layerId: UUID
    
    // This is the only closure we need now.
    let assignMetadata: (GraphEdge.ID, CGFloat, UUID) -> Void

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        guard path.count >= 2 else { return [] }
        
        var epicenter = Set<UUID>()
        var lastVertexID: UUID?
        
        for point in path {
            // Use a simple helper that ONLY creates a vertex if one doesn't exist.
            // It does NOT split edges. This is the rules' job.
            let currentVertexID = getOrCreateVertex(at: point, state: &state, context: context)
            epicenter.insert(currentVertexID)
            
            if let lastID = lastVertexID {
                // Connect the two points with a single, simple edge.
                // This may create a "leapfrog" edge that jumps over existing vertices,
                // which is exactly what we want the rules to fix.
                if let newEdge = state.addEdge(from: lastID, to: currentVertexID) {
                    assignMetadata(newEdge.id, width, layerId)
                }
            }
            lastVertexID = currentVertexID
        }
        return epicenter
    }
    
    // This helper is now extremely simple.
    private func getOrCreateVertex(at point: CGPoint, state: inout GraphState, context: TransactionContext) -> UUID {
        let tol = context.tolerance
        if let v = state.findVertex(at: point, tol: tol) {
            return v.id
        }
        let v = state.addVertex(at: point)
        return v.id
    }
}
