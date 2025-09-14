//
//  GraphMetadataPolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import Foundation

protocol GraphMetadataPolicy {
    
    func propagateMetadata(from oldEdges: [GraphEdge], to newEdge: GraphEdge)

    // --- ADDED ---
    /// Called by a rule *after* it has split a single edge into two new edges.
    /// This gives the policy a chance to transfer or copy metadata to the new edges.
    /// - Parameters:
    ///   - oldEdge: The original edge that was deleted during the split.
    ///   - newEdgeA: The first new edge created from the split.
    ///   - newEdgeB: The second new edge created from the split.
    func propagateMetadata(from oldEdge: GraphEdge, to newEdgeA: GraphEdge, and newEdgeB: GraphEdge)
}
