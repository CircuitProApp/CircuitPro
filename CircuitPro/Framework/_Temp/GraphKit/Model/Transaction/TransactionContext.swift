//
//  TransactionContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//


import CoreGraphics

public struct TransactionContext {
    public let grid: GridPolicy
    public var tol: CGFloat { grid.epsilon }
}