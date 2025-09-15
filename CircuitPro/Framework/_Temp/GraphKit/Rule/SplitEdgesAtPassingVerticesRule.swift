import Foundation
import CoreGraphics

struct SplitEdgesAtPassingVerticesRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        let tol = context.geometry.epsilon
        
        // Take a snapshot of edges at the start, as the state will be mutated.
        let initialEdges = Array(state.edges.values)
        let verts = Array(state.vertices.values)
        
        for edgeToSplit in initialEdges {
            // Ensure the edge we're processing hasn't already been deleted by a previous iteration.
            guard state.edges[edgeToSplit.id] != nil,
                  let p1 = state.vertices[edgeToSplit.start]?.point,
                  let p2 = state.vertices[edgeToSplit.end]?.point else { continue }
            
            // --- Step 1: Find all vertices that lie on this edge ---
            
            var mids: [GraphVertex] = []
            for v in verts {
                // A vertex is a "mid" point if it's not one of the edge's own endpoints.
                guard v.id != edgeToSplit.start && v.id != edgeToSplit.end else { continue }
                
                if state.isPoint(v.point, onSegmentBetween: p1, p2: p2, tol: tol) {
                    mids.append(v)
                }
            }
            
            // If there are no vertices on this edge, there's nothing to do.
            guard !mids.isEmpty else { continue }
            
            // --- Step 2: Build the full chain and sort it geometrically ---
            
            let (dx, dy) = (p2.x - p1.x, p2.y - p1.y)
            let len2 = max(dx*dx + dy*dy, tol*tol)
            mids.sort { lhs, rhs in
                let tL = ((lhs.point.x - p1.x) * dx + (lhs.point.y - p1.y) * dy) / len2
                let tR = ((rhs.point.x - p1.x) * dx + (rhs.point.y - p1.y) * dy) / len2
                return tL < tR
            }
            
            // Create a single, ordered list of all vertex IDs that will form the new chain.
            let chainOfIDs = [edgeToSplit.start] + mids.map { $0.id } + [edgeToSplit.end]
            
            // --- Step 3: Atomically replace the old edge with the new segments ---
            
            // Remove the original edge.
            state.removeEdge(edgeToSplit.id)
            
            // Create the new segments.
            var newEdges: [GraphEdge] = []
            for i in 0..<(chainOfIDs.count - 1) {
                if let newEdge = state.addEdge(from: chainOfIDs[i], to: chainOfIDs[i+1]) {
                    newEdges.append(newEdge)
                }
            }
            
            // --- Step 4: Propagate metadata to all new segments ---
            
            // CRITICAL: Inform the formal EdgePolicy about the N-way split.
            if !newEdges.isEmpty {
                // --- THIS IS THE FIX ---
                // Use the new, formal 'edgePolicy' property from the context.
                context.edgePolicy?.propagateMetadata(from: edgeToSplit, to: newEdges)
            }
        }
    }
}
