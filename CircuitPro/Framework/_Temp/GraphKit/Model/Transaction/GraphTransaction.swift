//
//  GraphTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

public protocol GraphTransaction {
    mutating func apply(to state: inout GraphState, context: TransactionContext) -> Set<UUID>
    
  
}

public protocol MetadataOnlyTransaction {}
