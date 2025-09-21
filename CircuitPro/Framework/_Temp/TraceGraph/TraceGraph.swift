import Foundation
import SwiftUI

@Observable
final class TraceGraph {
    let engine: GraphEngine
     
    var edgeMetadata: [GraphEdge.ID: TraceEdgeMetadata] = [:]

    init() {
        let ruleset = OctilinearGraphRuleset()
        let geometry = OctilinearGeometry(step: 1)
        let edgePolicy = TraceEdgePolicy()
        
        self.engine = GraphEngine(
            initialState: .empty,
            ruleset: ruleset,
            geometry: geometry,
            edgePolicy: edgePolicy
        )
        
        edgePolicy.traceGraph = self
    }
    
    func addTrace(path: [CGPoint], width: CGFloat, layerId: UUID) {
        var tx = AddTraceTransaction(
            path: path,
            width: width,
            layerId: layerId,
            assignMetadata: { [weak self] edgeID, traceWidth, newLayerId in
                let metadata = TraceEdgeMetadata(width: traceWidth, layerId: newLayerId)
                self?.edgeMetadata[edgeID] = metadata
            }
        )
        engine.execute(transaction: &tx)
    }
}
