//
//  LayerSide.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import Foundation

/// Defines the physical side or position of a layer in the board stackup.
enum LayerSide: Hashable, Codable {
    case front
    case back
    case inner(Int)
}
