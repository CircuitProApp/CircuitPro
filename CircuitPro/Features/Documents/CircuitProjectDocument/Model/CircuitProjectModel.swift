//
//  CircuitProjectModel.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.05.25.
//
import SwiftUI
import Observation

@Observable
class CircuitProject: Codable {
    var name: String
    var designs: [CircuitDesign]

    init(name: String, designs: [CircuitDesign]) {
        self.name = name
        self.designs = designs
    }

    enum CodingKeys: String, CodingKey {
        case _name = "name"
        case _designs = "designs"
    }
}

@Observable
class CircuitDesign: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    
    var componentInstances: [ComponentInstance]
    
    var directoryName: String {
        id.uuidString
    }

    init(id: UUID = UUID(), name: String, componentInstances: [ComponentInstance] = []) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.componentInstances = componentInstances
    }

    // MARK: - Hashable
    static func == (lhs: CircuitDesign, rhs: CircuitDesign) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _name = "name"
        case _componentInstances = "componentInstances"
    }
}



