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

@Resolvable(pattern: .nonInstantiable)
struct ReferenceDesignator {
    let prefix: String
    @Overridable
    var index: Int
    
    var label: String { "\(prefix)\(index)" }
}


@Storable
struct Component {
    @DefinitionStored
    var name: String
    @DefinitionStored
    var category: ComponentCategory
    
    @ResolvableProperty(
        definition: ReferenceDesignator.Definition.self,
        instance: [ReferenceDesignator.Override.self]
    )
    var referenceDesignator: ReferenceDesignator

    @StorableRelationship(deleteRule: .cascade, inverse: \Symbol.component)
    var symbol: Symbol
}


@Storable
struct Symbol {
    
    @DefinitionStored
    var primitives: [AnyCanvasPrimitive]
    @DefinitionStored
    var pins: [Pin]
    
    @DefinitionStored
    var component: Component.Definition
    
    @ResolvableProperty(
        definition: CircuitText.Definition.self,
        instance: [CircuitText.Instance.self, CircuitText.Override.self]
    )
    var texts: [CircuitText]
    
    @InstanceStored
    var position: CGPoint
    
    @InstanceStored
    var cardinalRotation: CardinalRotation
}
