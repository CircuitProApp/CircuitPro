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
    
    var propertyOverrides: [PropertyOverride]
    var adHocProperties: [InstanceAdHocProperty]

    var symbolInstance: SymbolInstance
    var footprintInstance: FootprintInstance?

    var referenceDesignatorIndex: Int

    init(
        id: UUID = UUID(),
        componentUUID: UUID,
        propertyOverrides: [PropertyOverride] = [],
        adHocProperties: [InstanceAdHocProperty] = [],
        symbolInstance: SymbolInstance,
        footprintInstance: FootprintInstance? = nil,
        reference: Int = 0
    ) {
        self.id = id
        self.componentUUID = componentUUID
        self.propertyOverrides = propertyOverrides
        self.adHocProperties = adHocProperties
        self.symbolInstance = symbolInstance
        self.footprintInstance = footprintInstance
        self.referenceDesignatorIndex = reference
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _componentUUID = "componentUUID"
        case _propertyOverrides = "propertyOverrides"
        case _adHocProperties = "adHocProperties"
        case _symbolInstance = "symbolInstance"
        case _footprintInstance = "footprintInstance"
        case _referenceDesignatorIndex = "referenceDesignatorIndex"
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
