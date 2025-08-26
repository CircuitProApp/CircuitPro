//
//  VertexOwnership.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation
// If you haven't moved these to a shared file yet, keep them here.
// If you already created a WirePrimitives.swift, remove these duplicates.
enum VertexOwnership: Hashable {
    case free
    case pin(ownerID: UUID, pinID: UUID)
    case detachedPin // Temporarily marks a vertex that was a pin but is now being dragged
}

