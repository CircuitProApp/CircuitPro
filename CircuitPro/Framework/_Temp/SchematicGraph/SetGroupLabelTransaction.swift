//
//  SetGroupLabelTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/27/25.
//


import Foundation

struct SetGroupLabelTransaction: GraphTransaction, MetadataOnlyTransaction {
    let groupID: UUID
    let label: String
    let assign: (UUID, String) -> Void

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        // Update domain metadata
        assign(groupID, label)
        // Return all vertex IDs in this group as an epicenter if the UI wants to
        // scope updates. Rules will be skipped due to MetadataOnlyTransaction.
        let seeds = state.vertices.compactMap { (vid, v) in
            v.groupID == groupID ? vid : nil
        }
        return Set(seeds)
    }
}