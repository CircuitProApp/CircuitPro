//
//  Model.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/12/25.
//

import SwiftUI
import SwiftData

@Model
class Model {

    @Attribute(.unique)
    var uuid: UUID
    var name: String
    var thumbnail: String?

    init(uuid: UUID = UUID(), name: String, thumbnail: String? = nil) {
        self.uuid = uuid
        self.name = name
        self.thumbnail = thumbnail
    }
}
