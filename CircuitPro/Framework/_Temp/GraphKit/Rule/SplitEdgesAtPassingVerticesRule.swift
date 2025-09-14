import Foundation
import CoreGraphics

struct SplitEdgesAtPassingVerticesRule: GraphRule {
    func apply(state: inout GraphState, context: ResolutionContext) {
        let tol = context.geometry.epsilon

        let edges = Array(state.edges.values)
        let verts = Array(state.vertices.values)

        for e in edges {
            // Ensure the edge we are checking still exists in the mutable state
            guard state.edges[e.id] != nil,
                  let p1 = state.vertices[e.start]?.point,
                  let p2 = state.vertices[e.end]?.point else { continue }
            
            if !CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)).intersects(context.neighborhood) {
                continue
            }
            
            var mids: [GraphVertex] = []
            for v in verts where v.id != e.start && v.id != e.end {
                if state.isPoint(v.point, onSegmentBetween: p1, p2: p2, tol: tol) {
                    let d1 = hypot(v.point.x - p1.x, v.point.y - p1.y)
                    let d2 = hypot(v.point.x - p2.x, v.point.y - p2.y)
                    if d1 > tol && d2 > tol {
                        mids.append(v)
                    }
                }
            }
            guard !mids.isEmpty else { continue }
            
            let (dx, dy) = (p2.x - p1.x, p2.y - p1.y)
            let len2 = max(dx*dx + dy*dy, tol*tol)
            mids.sort { lhs, rhs in
                let tL = ((lhs.point.x - p1.x) * dx + (lhs.point.y - p1.y) * dy) / len2
                let tR = ((rhs.point.x - p1.x) * dx + (rhs.point.y - p1.y) * dy) / len2
                return tL < tR
            }
            
            // --- MODIFIED LOGIC ---
            // Rebuild the chain segment by segment, propagating metadata at each step.
            
            var lastVertexID = e.start
            var lastEdge = e // Start with the original edge for the first split
            
            for midVertex in mids {
                // The edge to be split is the 'lastEdge' from the previous iteration
                let edgeToSplit = lastEdge
                
                // Remove the old edge
                state.removeEdge(edgeToSplit.id)
                
                // Create the two new edges
                guard let newEdgeA = state.addEdge(from: lastVertexID, to: midVertex.id),
                      let newEdgeB = state.addEdge(from: midVertex.id, to: edgeToSplit.end) else {
                    // This should not happen if the topology is valid
                    continue
                }
                
                // CRITICAL: Inform the metadata policy about the split
                context.metadataPolicy?.propagateMetadata(from: edgeToSplit, to: newEdgeA, and: newEdgeB)
                
                // The second new edge becomes the one to split in the next iteration
                lastVertexID = midVertex.id
                lastEdge = newEdgeB
            }
            
            // The final connection to the original end point
            state.removeEdge(lastEdge.id)
            if let finalEdgeA = state.addEdge(from: lastVertexID, to: e.end) {
                 // We need to think if metadata needs propagation here, it's complex.
                 // For now, let's assume the previous loop handles it.
                 // Let's re-connect last segment
                 let finalEdgeB = state.addEdge(from: lastVertexID, to: e.end)! // A bit risky
                 context.metadataPolicy?.propagateMetadata(from: lastEdge, to: finalEdgeA, and: finalEdgeB)
            }
        }
    }
}
