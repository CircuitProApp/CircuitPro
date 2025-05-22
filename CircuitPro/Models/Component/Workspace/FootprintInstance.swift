//
//  SymbolInstance 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import SwiftData
import SwiftUI

@Model
final class FootprintInstance {

    @Attribute(.unique)
    var uuid: UUID

    var footprintUUID: UUID

    init(uuid: UUID = UUID(), footprintId: UUID) {
        self.uuid = uuid
        self.footprintUUID = footprintId
    }
}
