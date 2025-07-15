//
//  DesignComponent.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/7/25.
//

import SwiftUI

struct DesignComponent: Identifiable, Hashable {

    // library object (SwiftData)
    let definition: Component

    // stored in the NSDocument
    let instance: ComponentInstance

    var id: UUID { instance.id }

    var reference: String {
        definition.abbreviation + instance.reference.description
    }
}
