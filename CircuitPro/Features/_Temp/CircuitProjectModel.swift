//
//  CircuitProjectModel.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.05.25.
//


import SwiftUI
import UniformTypeIdentifiers
import Observation

// MARK: - Data Model
class CircuitProjectModel: Codable {
    var name: String
    var version: String

    init(name: String = "Untitled", version: String = "1.0") {
        self.name = name
        self.version = version
    }
}

// MARK: - Custom UTI

extension UTType {
    /// Descriptor file users double‑click (a single JSON file)
    static let circuitProject = UTType(exportedAs: "app.circuitpro.project")
}
