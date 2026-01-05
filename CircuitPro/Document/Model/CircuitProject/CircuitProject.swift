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
