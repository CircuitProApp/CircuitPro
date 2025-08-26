//
//  GraphTransaction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

public protocol GraphTransaction {
    // Existing mutating apply stays for now
    mutating func apply(to state: inout GraphState) -> Set<UUID>
}

public protocol MetadataOnlyTransaction {}
