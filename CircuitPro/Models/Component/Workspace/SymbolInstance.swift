//
//  ComponentInstance 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import SwiftData
import SwiftUI

@Model
final class SymbolInstance {

    @Attribute(.unique)
    var uuid: UUID

    var symbolUUID: UUID
    var position: SDPoint
    var rotation: CGFloat

    init(uuid: UUID = UUID(), symbolId: UUID, position: SDPoint, rotation: CGFloat = 0) {
        self.uuid = uuid
        self.symbolUUID = symbolId
        self.position = position
        self.rotation = rotation
    }
}
