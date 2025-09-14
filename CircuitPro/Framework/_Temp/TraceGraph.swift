//
//  TraceGraph.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import Foundation
import SwiftUI

@Observable
final class TraceGraph {
    let engine: GraphEngine
     
     var traceData: [GraphEdge.ID: (width: CGFloat, layerId: UUID)] = [:]
     var onModelDidChange: (() -> Void)?

     init() {
         // --- THIS IS THE KEY CHANGE ---
         // We now instantiate our new octilinear components.
         let ruleset = OctilinearGraphRuleset()
         let geometry = OctilinearGeometry(step: 1)
         // ---
         
         self.engine = GraphEngine(
             initialState: .empty,
             ruleset: ruleset,
             geometry: geometry
         )

         engine.onChange = { [weak self] _, _ in
             self?.onModelDidChange?()
         }
     }
    
    /// Adds a single, straight trace segment to the graph.
    // --- THIS IS THE NEW FUNCTION ---
      /// Processes a `TraceRequestNode` by creating a chain of vertices and edges for its path.
      func addTrace(path: [CGPoint], width: CGFloat, layerId: UUID) {
          guard path.count >= 2 else { return }
          
          var epicenter = Set<UUID>()
          var lastVertexID: UUID?
          
          // 1. Iterate through the points in the path.
          for point in path {
              // a. Get or create a vertex at the current point.
              var tx = GetOrCreateVertexTransaction(point: point)
              engine.execute(transaction: &tx)
              guard let currentVertexID = tx.createdID else { continue }
              
              epicenter.insert(currentVertexID)
              
              // b. If this isn't the first point, connect the last vertex to the current one.
              if let lastID = lastVertexID {
                  var currentState = engine.currentState
                  if let newEdge = currentState.addEdge(from: lastID, to: currentVertexID) {
                      traceData[newEdge.id] = (width, layerId)
                  }
                  // We update the state directly inside the loop for simplicity.
                  engine.replaceState(currentState)
              }
              
              lastVertexID = currentVertexID
          }
          
          // 2. After creating all segments, run a final resolve operation.
          var loadTx = LoadStateTransaction(newState: engine.currentState, epicenter: epicenter)
          engine.execute(transaction: &loadTx)
      }
}
