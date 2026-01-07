//
//  GraphTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

protocol GraphTransaction {
    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID>
}
