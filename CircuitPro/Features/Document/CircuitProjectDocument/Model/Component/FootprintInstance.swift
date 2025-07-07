//
//  FootprintInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI

@Observable
final class FootprintInstance: Identifiable, Codable {

    var id: UUID

    var footprintUUID: UUID

    init(id: UUID = UUID(), footprintUUID: UUID) {
        self.id = id
        self.footprintUUID = footprintUUID
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _footprintUUID = "footprintUUID"
    }
}
