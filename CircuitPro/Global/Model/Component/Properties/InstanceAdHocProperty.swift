//
//  InstanceAdHocProperty.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//


import Foundation

/// Defines a full, self-contained property added to a single component instance at runtime.
/// It does not correspond to a PropertyDefinition in the master component.
struct InstanceAdHocProperty: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var key: PropertyKey // The key chosen by the user from the enum
    var value: PropertyValue
    var unit: Unit
}