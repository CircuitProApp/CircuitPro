//
//  ComponentInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import SwiftData
import SwiftUI

@Model
final class ComponentInstance {

    @Attribute(.unique)
    var uuid: UUID

    var componentUUID: UUID
    var properties: [ComponentProperty]
    var symbolInstance: SymbolInstance
    var footprintInstance: FootprintInstance?
    var design: Design?

    init(
        uuid: UUID = UUID(),
        componentId: UUID,
        properties: [ComponentProperty] = [],
        symbolInstance: SymbolInstance,
        footprintInstance: FootprintInstance? = nil,
        design: Design? = nil
    ) {
        self.uuid = uuid
        self.componentUUID = componentId
        self.properties = properties
        self.symbolInstance = symbolInstance
        self.footprintInstance = footprintInstance
        self.design = design
    }
}
