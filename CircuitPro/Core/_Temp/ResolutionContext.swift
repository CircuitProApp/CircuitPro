//
//  ResolutionContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

/// A context object passed to a ruleset, providing information about the initial change.
public struct ResolutionContext {
    public let epicenter: Set<UUID>
    public let grid: GridPolicy
    public let neighborhood: CGRect  // AABB grown around epicenter
}

