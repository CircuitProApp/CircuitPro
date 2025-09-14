//
//  BoardSide.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import Foundation

/// Defines the physical side of the board a component footprint is placed on.
enum BoardSide: String, Codable, Hashable {
    case front
    case back
}
