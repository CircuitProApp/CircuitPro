//
//  OwnershipLookupBox.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

final class OwnershipLookupBox {
    var lookup: ((UUID) -> VertexOwnership?)?
}
