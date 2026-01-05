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
    
    var drawingOrder: Int {
        switch self {
        case .back:
            return 0
        case .inner(let index):
            // Inner layers are stacked on top of the back layer.
            return 100 + index
        case .front:
            return 1000 // A high number to ensure it's drawn last.
        }
    }
}

