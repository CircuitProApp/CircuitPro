//
//  ReleasePinsTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

// Domain-level transaction: release all pins owned by a component by
// updating the schematic ownership map. It does not mutate GraphState geometry,
// but returns an epicenter so the engine will run rules around those vertices.
struct ReleasePinsTransaction: GraphTransaction {
    let ownerID: UUID

    // Inject ownership accessors from the domain layer (WireGraph)
    let lookup: (UUID) -> VertexOwnership?
    let assign: (UUID, VertexOwnership) -> Void

    // Not marked MetadataOnlyTransaction on purpose: we want rules to run
    // after the ownership change (e.g., cull isolated vertices, merge, etc.)
    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID> {
        var epicenter: Set<UUID> = []
        for vid in state.vertices.keys {
            if case .pin(let o, _) = lookup(vid), o == ownerID {
                assign(vid, .free)
                epicenter.insert(vid)
            }
        }
        return epicenter
    }
}
