//
//  EdgePolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import Foundation

/// A protocol that defines a domain-specific policy for managing edge metadata
/// during generic graph transformations performed by a ruleset.
protocol EdgePolicy {
    
    /// Called by a rule *after* it has merged multiple edges into a single new edge.
    /// - Parameters:
    ///   - oldEdges: The collection of edges that were deleted during the merge.
    ///   - newEdge: The single new edge that was created to replace them.
    func propagateMetadata(from oldEdges: [GraphEdge], to newEdge: GraphEdge)

    /// Called by a rule *after* it has split a single edge into multiple new edge segments.
    /// - Parameters:
    ///   - oldEdge: The original edge that was deleted.
    ///   - newEdges: The array of new edge segments that were created in its place.
    func propagateMetadata(from oldEdge: GraphEdge, to newEdges: [GraphEdge])
    
    /// Asks the policy if a vertex should be preserved during a collapse operation,
    /// even if it's topologically redundant. This is used to preserve "seams"
    /// where edge metadata (like trace width or layer) changes.
    /// - Parameters:
    ///   - vertex: The vertex being considered for removal.
    ///   - edgesInRun: The edges connected to this vertex that are part of the linear run.
    /// - Returns: `true` to force the rule to keep the vertex, `false` otherwise.
    func shouldPreserveVertex(_ vertex: GraphVertex, connecting edgesInRun: [GraphEdge]) -> Bool
}

// Provide default implementations so conforming types only need to implement what they need.
extension EdgePolicy {
    func propagateMetadata(from oldEdges: [GraphEdge], to newEdge: GraphEdge) {}
    func propagateMetadata(from oldEdge: GraphEdge, to newEdges: [GraphEdge]) {}
    func shouldPreserveVertex(_ vertex: GraphVertex, connecting edgesInRun: [GraphEdge]) -> Bool {
        return false
    }
}
