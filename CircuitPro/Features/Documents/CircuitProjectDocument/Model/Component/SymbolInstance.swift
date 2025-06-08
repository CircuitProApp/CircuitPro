//
//  SymbolInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI

@Observable
final class SymbolInstance: Identifiable, Codable {

    var id: UUID

    var symbolUUID: UUID
    var position: CGPoint
    var rotation: CGFloat

    init(id: UUID = UUID(), symbolUUID: UUID, position: CGPoint, rotation: CGFloat = 0) {
        self.id = id
        self.symbolUUID = symbolUUID
        self.position = position
        self.rotation = rotation
    }
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _symbolUUID = "symbolUUID"
        case _position = "position"
        case _rotation = "rotation"
    }
}
