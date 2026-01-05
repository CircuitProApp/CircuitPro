//
//  Footprint.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//
import SwiftUI
import SwiftData

@Model
class FootprintDefinition {

    @Attribute(.unique)
    var uuid: UUID
    var name: String
    var footprintType: FootprintType
    var primitives: [AnyCanvasPrimitive]
    var pads: [Pad]
    
    var textDefinitions: [CircuitText.Definition]
    
    var components: [ComponentDefinition]

    init(
        uuid: UUID = UUID(),
        name: String,
        footprintType: FootprintType = .throughHole,
        primitives: [AnyCanvasPrimitive],
        pads: [Pad] = [],
        textDefinitions: [CircuitText.Definition] = [],
        components: [ComponentDefinition] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.footprintType = footprintType
        self.primitives = primitives
        self.pads = pads
        self.textDefinitions = textDefinitions
        self.components = components
    }
}
