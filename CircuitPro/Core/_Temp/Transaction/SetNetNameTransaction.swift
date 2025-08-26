//
//  SetNetNameTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


import Foundation
// Set a net's name (pure metadata change)
struct SetNetNameTransaction: GraphTransaction {
    let netID: UUID
    let name: String

    mutating func apply(to state: inout GraphState) -> Set<UUID> {
        state.netNames[netID] = name
        return []
    }
}
