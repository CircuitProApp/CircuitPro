//
//  SetGroupNameTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct SetGroupNameTransaction: GraphTransaction, MetadataOnlyTransaction {
    let netID: UUID
    let name: String

    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        state.groupNames[netID] = name
        return []
    }
}
