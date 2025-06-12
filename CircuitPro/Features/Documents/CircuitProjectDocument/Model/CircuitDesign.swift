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
    
    var directoryName: String {
        id.uuidString
    }

    init(id: UUID = UUID(), name: String, componentInstances: [ComponentInstance] = []) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.componentInstances = componentInstances
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _name = "name"
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
