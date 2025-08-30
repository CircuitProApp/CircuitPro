//
//  ComponentItem.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftData
import Foundation
import KeyPathable
import Storable
import Resolvable

@Model
@KeyPathable
class ComponentDefinition {

    @Attribute(.unique)
    var uuid: UUID

    @KeyPath
    @Attribute(.unique)
    var name: String

    @KeyPath
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
        referenceDesignatorPrefix: String,
        symbol: SymbolDefinition? = nil,
        footprints: [FootprintDefinition] = [],
        category: ComponentCategory,
        propertyDefinitions: [Property.Definition] = []
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

