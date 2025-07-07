//
//  DesignComponent.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/7/25.
//

import SwiftUI

struct DesignComponent: Identifiable, Hashable {
    let definition: Component          // library object (SwiftData)
    let instance:   ComponentInstance  // stored in the NSDocument

    var id: UUID { instance.id }
    
    var reference: String {
        definition.abbreviation + instance.reference.description
    }
}
