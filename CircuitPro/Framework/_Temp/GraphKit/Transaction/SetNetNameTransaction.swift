//
//  SetNetNameTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct SetNetNameTransaction: GraphTransaction, MetadataOnlyTransaction {
    let netID: UUID
    let name: String

    mutating func apply(to state: inout GraphState) -> Set<UUID> {
        state.netNames[netID] = name
        return []
    }
}
