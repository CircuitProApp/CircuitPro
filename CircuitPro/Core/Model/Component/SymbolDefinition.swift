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
    @Attribute(.unique)
    var name: String

    var component: ComponentDefinition?
    var primitives: [AnyCanvasPrimitive]
    var pins: [Pin]
    
    var textDefinitions: [CircuitText.Definition]

    init(
        uuid: UUID = UUID(),
        name: String,
        component: ComponentDefinition? = nil,
        primitives: [AnyCanvasPrimitive] = [],
        pins: [Pin] = [],
        textDefinitions: [CircuitText.Definition] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.component = component
        self.primitives = primitives
        self.pins = pins
        self.textDefinitions = textDefinitions
    }
}
