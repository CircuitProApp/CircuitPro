//
//  GraphVertex.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import SwiftUI

struct GraphVertex: Identifiable, Hashable, Equatable {
    let id: UUID
    var point: CGPoint
    var groupID: UUID?
}
