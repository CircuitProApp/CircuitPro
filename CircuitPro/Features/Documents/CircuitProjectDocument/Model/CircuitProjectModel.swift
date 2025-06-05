//
//  CircuitProjectModel.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.05.25.
//
import SwiftUI
import UniformTypeIdentifiers
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
    var folderPath: String

    init(id: UUID = UUID(), name: String, folderPath: String) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
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
        case _folderPath = "folderPath"
    }
}



// MARK: - Custom UTI
extension UTType {
    /// Descriptor file users double‑click (a single JSON file)
    static let circuitProject = UTType(exportedAs: "app.circuitpro.project", conformingTo: .package)
    static let schematic = UTType(exportedAs: "app.circuitpro.schematic")
    static let pcbLayout = UTType(exportedAs: "app.circuitpro.pcb-layout")
}
