//
//  CircuitDesign.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 10.06.25.
//

import SwiftUI
import Observation

@Observable
class CircuitDesign: Codable, Identifiable {

    var id: UUID
    var name: String
    var componentInstances: [ComponentInstance] = []
    var wires: [Wire] = []
    var wirePoints: [WireVertex] = []
    var wireLinks: [WireSegment] = []
    var traces: [TraceSegment] = []
    // --- ADDED: Each design now has its own layer stackup ---
    var layers: [LayerType] = []

    var directoryName: String {
        id.uuidString
    }

    // --- MODIFIED: The initializer now creates a default layer stackup ---
    init(
        id: UUID = UUID(),
        name: String,
        componentInstances: [ComponentInstance] = [],
        wires: [Wire] = [],
        wirePoints: [WireVertex] = [],
        wireLinks: [WireSegment] = [],
        traces: [TraceSegment] = []
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.componentInstances = componentInstances
        self.wires = wires
        self.wirePoints = wirePoints
        self.wireLinks = wireLinks
        self.traces = traces
        // When a new design is created, generate its standard layers.
        self.layers = LayerType.defaultStackup(layerCount: .two)
    }

    // --- MODIFIED: Update Codable conformance to include layers ---
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _name = "name"
        case _componentInstances = "componentInstances"
        case _wires = "wires"
        case _wirePoints = "wirePoints"
        case _wireLinks = "wireLinks"
        case _traces = "traces"
        case _layers = "layers"
    }

    // This initializer is used when decoding from a file
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: ._id)
        self.name = try container.decode(String.self, forKey: ._name)
        self.componentInstances = try container.decode([ComponentInstance].self, forKey: ._componentInstances)
        self.wires = try container.decode([Wire].self, forKey: ._wires)
        self.wirePoints = try container.decodeIfPresent([WireVertex].self, forKey: ._wirePoints) ?? []
        self.wireLinks = try container.decodeIfPresent([WireSegment].self, forKey: ._wireLinks) ?? []
        self.traces = try container.decodeIfPresent([TraceSegment].self, forKey: ._traces) ?? []

        // For backward compatibility: if the 'layers' key doesn't exist in an old project file,
        // decode it as nil and then generate the default stackup.
        self.layers = try container.decodeIfPresent([LayerType].self, forKey: ._layers) ?? LayerType.defaultStackup(layerCount: .two)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: ._id)
        try container.encode(self.name, forKey: ._name)
        try container.encode(self.componentInstances, forKey: ._componentInstances)
        try container.encode(self.wires, forKey: ._wires)
        try container.encode(self.wirePoints, forKey: ._wirePoints)
        try container.encode(self.wireLinks, forKey: ._wireLinks)
        try container.encode(self.traces, forKey: ._traces)
        try container.encode(self.layers, forKey: ._layers)
    }
}

extension CircuitDesign: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CircuitDesign, rhs: CircuitDesign) -> Bool {
        lhs.id == rhs.id
    }
}
