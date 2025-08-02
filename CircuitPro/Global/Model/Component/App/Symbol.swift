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
class Symbol {

    @Attribute(.unique)
    var uuid: UUID
    @Attribute(.unique)
    var name: String

    var component: Component?
    var primitives: [AnyPrimitive]
    var pins: [Pin]
    
    var textDefinitions: [TextDefinition]

    init(
        uuid: UUID = UUID(),
        name: String,
        component: Component? = nil,
        primitives: [AnyPrimitive] = [],
        pins: [Pin] = [],
        textDefinitions: [TextDefinition] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.component = component
        self.primitives = primitives
        self.pins = pins
        self.textDefinitions = textDefinitions
    }
}
