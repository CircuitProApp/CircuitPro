//
//  TransactionContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import CoreGraphics

struct TransactionContext {
    let geometry: GeometryPolicy
    var tolerance: CGFloat { geometry.epsilon }
}
