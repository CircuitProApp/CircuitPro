//
//  VertexOwnership.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

enum VertexOwnership: Hashable {
    case free
    case pin(ownerID: UUID, pinID: UUID)
    case detachedPin
}

