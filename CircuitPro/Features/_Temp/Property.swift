//
//  Property.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import ResolvableMacro
import SwiftUI

@Resolvable
struct Property {
   
    var key: PropertyKey
    var unit: Unit
    var warnsOnEdit: Bool = false
    
  
    @Overridable var value: PropertyValue
}
