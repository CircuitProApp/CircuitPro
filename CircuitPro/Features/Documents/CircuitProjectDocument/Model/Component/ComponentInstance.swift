//
//  ComponentInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI

@Observable
final class ComponentInstance: Identifiable, Codable {

    var id: UUID

    var componentUUID: UUID
    var properties: [ComponentProperty]
    var symbolInstance: SymbolInstance
    var footprintInstance: FootprintInstance?

    init(
        id: UUID = UUID(),
        componentUUID: UUID,
        properties: [ComponentProperty] = [],
        symbolInstance: SymbolInstance,
        footprintInstance: FootprintInstance? = nil
    ) {
        self.id = id
        self.componentUUID = componentUUID
        self.properties = properties
        self.symbolInstance = symbolInstance
        self.footprintInstance = footprintInstance
    }
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _componentUUID = "componentUUID"
        case _properties = "properties"
        case _symbolInstance = "symbolInstance"
        case _footprintInstance = "footprintInstance"
    }
}

// MARK: - Hashable
extension ComponentInstance: Hashable {
    
    // Two component instances are considered equal if they carry the same `id`.
    public static func == (lhs: ComponentInstance, rhs: ComponentInstance) -> Bool {
        lhs.id == rhs.id
    }
    
    // The `id` is also the only thing we need to hash – it is already unique.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
