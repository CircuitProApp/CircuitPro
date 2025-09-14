import Foundation
import SwiftUI

@Observable
final class TraceGraph {
    let engine: GraphEngine
     
     var traceData: [GraphEdge.ID: (width: CGFloat, layerId: UUID)] = [:]
     var onModelDidChange: (() -> Void)?

    init() {
        let ruleset = OctilinearGraphRuleset()
        let geometry = OctilinearGeometry(step: 1)
        let metadataPolicy = TraceMetadataPolicy()
        
        self.engine = GraphEngine(
            initialState: .empty,
            ruleset: ruleset,
            geometry: geometry,
            metadataPolicy: metadataPolicy
        )
        
        metadataPolicy.traceGraph = self

        engine.onChange = { [weak self] _, _ in
            self?.onModelDidChange?()
        }
    }
    
    func addTrace(path: [CGPoint], width: CGFloat, layerId: UUID) {
        // --- MODIFIED: Provide the new lookup closure ---
        var tx = AddTraceTransaction(
            path: path,
            width: width,
            layerId: layerId,
            // This closure allows the transaction to look up existing metadata.
            lookupMetadata: { [weak self] edgeID in
                return self?.traceData[edgeID]
            },
            // This closure allows the transaction to write new metadata.
            assignMetadata: { [weak self] edgeID, traceWidth, newLayerId in
                self?.traceData[edgeID] = (width: traceWidth, layerId: newLayerId)
            }
        )
        
        engine.execute(transaction: &tx)
    }
}
