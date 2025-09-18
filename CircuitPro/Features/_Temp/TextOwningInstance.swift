//
//  TextOwningInstance.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/18/25.
//

// Assuming this is defined in one of your model files (e.g., ComponentInstance.swift, or a CoreModels.swift)

import Foundation

// A protocol that both SymbolInstance and FootprintInstance should conform to.
// It defines the minimal interface required for AnchoredTextNode to function.
protocol TextOwningInstance: AnyObject, Identifiable {
    // Identifiable is needed for the 'id' property.
    // AnyObject is needed for 'unowned let'.
    
    // This method is used by AnchoredTextNode to commit changes back to its owner.
    func apply(_ editedText: CircuitText.Resolved)
    
    // If AnchoredTextNode needs other properties from its owner (e.g., `isPlaced`, `definition`),
    // those would also need to be part of this protocol. For now, `id` and `apply` are sufficient.
}

// Make your existing instance types conform to this protocol:
// (These extensions would go in the files where SymbolInstance and FootprintInstance are defined)

// Example for SymbolInstance:
 extension SymbolInstance: TextOwningInstance {

 }

// Example for FootprintInstance:
 extension FootprintInstance: TextOwningInstance {

 }
