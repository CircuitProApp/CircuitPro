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

    var directoryName: String {
        id.uuidString
    }

    init(id: UUID = UUID(), name: String, componentInstances: [ComponentInstance] = [], wires: [Wire] = []) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.componentInstances = componentInstances
        self.wires = wires
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _name = "name"
        case _wires = "wires"
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
