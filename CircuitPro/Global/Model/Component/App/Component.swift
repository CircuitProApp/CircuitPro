//
//  ComponentItem.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftData
import Foundation

@Model
class Component {

    @Attribute(.unique)
    var uuid: UUID

    @Attribute(.unique)
    var name: String

    @Attribute(.unique)
    var referenceDesignatorPrefix: String

    @Relationship(deleteRule: .cascade, inverse: \Symbol.component)
    var symbol: Symbol?

    var footprints: [Footprint]
    var category: ComponentCategory?
    var package: PackageType?
    var propertyDefinitions: [PropertyDefinition]

    init(
        uuid: UUID = UUID(),
        name: String,
        referenceDesignatorPrefix: String,
        symbol: Symbol? = nil,
        footprints: [Footprint] = [],
        category: ComponentCategory? = nil,
        package: PackageType? = nil,
        propertyDefinitions: [PropertyDefinition] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.referenceDesignatorPrefix = referenceDesignatorPrefix
        self.symbol = symbol
        self.footprints = footprints
        self.category = category
        self.package = package
        self.propertyDefinitions = propertyDefinitions
    }
}
