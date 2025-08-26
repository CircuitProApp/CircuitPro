//
//  ResolutionContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


/// A context object passed to a ruleset, providing information about the initial change.
struct ResolutionContext {
    /// The set of vertex IDs that were directly moved or created by the user's transaction.
    let epicenter: Set<WireVertex.ID>
}