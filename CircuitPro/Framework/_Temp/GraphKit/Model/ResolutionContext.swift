//
//  ResolutionContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

/// A context object passed to a ruleset, providing information about the initial change.
struct ResolutionContext {
    let epicenter: Set<UUID>
    let geometry: GeometryPolicy
    let neighborhood: CGRect
    let policy: VertexPolicy?   // new
}

