//
//  TransactionContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import CoreGraphics

struct TransactionContext {
    let grid: GridPolicy
    var tolerance: CGFloat { grid.epsilon }
}
