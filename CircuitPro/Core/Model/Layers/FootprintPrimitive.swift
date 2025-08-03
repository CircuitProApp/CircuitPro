//
//  LayeredPrimitive.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/7/25.
//
import SwiftUI

struct FootprintPrimitive: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var primitive: AnyPrimitive
    var layerType: LayerType
}
