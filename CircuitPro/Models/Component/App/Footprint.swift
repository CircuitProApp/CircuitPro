//
//  Footprint.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//
import SwiftUI
import SwiftData

@Model
class Footprint {

    @Attribute(.unique)
    var uuid: UUID
    var name: String
    var footprintType: FootprintType
    var footprintPrimitives: [FootprintPrimitive]
    var pads: [Pad]
    var components: [Component]

    init(
        uuid: UUID = UUID(),
        name: String,
        footprintType: FootprintType = .throughHole,
        layeredPrimitives: [FootprintPrimitive],
        pads: [Pad] = [],
        components: [Component] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.footprintType = footprintType
        self.footprintPrimitives = layeredPrimitives
        self.pads = pads
        self.components = components
    }
}
