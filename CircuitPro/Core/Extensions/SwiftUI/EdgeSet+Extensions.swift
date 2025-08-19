//
//  EdgeSet+Extensions.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

extension Edge.Set {
    static func excluding(_ edges: Edge.Set) -> Edge.Set {
        let allEdges: Edge.Set = [.top, .bottom, .leading, .trailing]
        return allEdges.subtracting(edges)
    }
}
