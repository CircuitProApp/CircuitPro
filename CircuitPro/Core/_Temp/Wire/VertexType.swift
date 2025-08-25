//
//  VertexType.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import Foundation

/// The type of vertex that was hit.
public enum VertexType {
    /// An endpoint of a wire.
    case endpoint
    /// A corner in a wire.
    case corner
    /// A junction where multiple wires meet.
    case junction
}
