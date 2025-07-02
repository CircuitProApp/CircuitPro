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
    
    var reference: Int

    init(
        id: UUID = UUID(),
        componentUUID: UUID,
        properties: [ComponentProperty] = [],
        symbolInstance: SymbolInstance,
        footprintInstance: FootprintInstance? = nil,
        reference: Int = 0
    ) {
        self.id = id
        self.componentUUID = componentUUID
        self.properties = properties
        self.symbolInstance = symbolInstance
        self.footprintInstance = footprintInstance
        self.reference = reference
    }
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _componentUUID = "componentUUID"
        case _properties = "properties"
        case _symbolInstance = "symbolInstance"
        case _footprintInstance = "footprintInstance"
        case _reference = "reference"
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
