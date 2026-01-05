//
//  ComponentItem.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftData
import Foundation

@Model
class ComponentDefinition {

    @Attribute(.unique)
    var uuid: UUID

    @Attribute(.unique)
    var name: String

    @Attribute(.unique)
    var referenceDesignatorPrefix: String

    @Relationship(deleteRule: .cascade, inverse: \SymbolDefinition.component)
    var symbol: SymbolDefinition?

    var footprints: [FootprintDefinition]
    var category: ComponentCategory
    var propertyDefinitions: [Property.Definition]

    init(
        uuid: UUID = UUID(),
        name: String,
        category: ComponentCategory,
        referenceDesignatorPrefix: String,
        propertyDefinitions: [Property.Definition] = [],
        symbol: SymbolDefinition? = nil,
        footprints: [FootprintDefinition] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.referenceDesignatorPrefix = referenceDesignatorPrefix
        self.symbol = symbol
        self.footprints = footprints
        self.category = category
        self.propertyDefinitions = propertyDefinitions
    }
}

