//
//  Symbol.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftUI
import SwiftData
import Foundation

@Model
class SymbolDefinition {

    @Attribute(.unique)
    var uuid: UUID

    var primitives: [AnyCanvasPrimitive]
    var pins: [Pin]
    
    var textDefinitions: [CircuitText.Definition]
    
    var component: ComponentDefinition?

    init(
        uuid: UUID = UUID(),
        primitives: [AnyCanvasPrimitive] = [],
        pins: [Pin] = [],
        textDefinitions: [CircuitText.Definition] = [],
        component: ComponentDefinition? = nil
    ) {
        self.uuid = uuid
        self.component = component
        self.primitives = primitives
        self.pins = pins
        self.textDefinitions = textDefinitions
    }
}
