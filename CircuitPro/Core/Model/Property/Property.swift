//
//  Property.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import Resolvable
import SwiftUI

@Resolvable
struct Property {
   
    var key: PropertyKey
    
    @Overridable var value: PropertyValue
    
    @Overridable(\Unit.prefix, as: SIPrefix.self)
    var unit: Unit
    
    var warnsOnEdit: Bool = false
}
