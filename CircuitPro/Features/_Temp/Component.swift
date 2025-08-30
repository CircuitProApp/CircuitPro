//
//  Component.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/30/25.
//

import Resolvable
import Storable
import SwiftUI

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

    @StorableRelationship(deleteRule: .cascade)
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
