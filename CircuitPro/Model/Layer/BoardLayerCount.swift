//
//  BoardLayerCount.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

/// Represents the total number of copper layers in a manufacturable PCB.
enum BoardLayerCount: Int, Displayable {
    case two = 2
    case four = 4
    case six = 6
    case eight = 8
    case ten = 10
    case twelve = 12
    case fourteen = 14
    case sixteen = 16

    /// The number of inner copper layers for this board type.
    var innerLayerCount: Int {
        guard self.rawValue > 2 else { return 0 }
        return self.rawValue - 2
    }
    
    var label: String {
        switch self {
        case .two: return "2"
        case .four: return "4"
        case .six: return "6"
        case .eight: return "8"
        case .ten: return "10"
        case .twelve: return "12"
        case .fourteen: return "14"
        case .sixteen: return "16"
        }
    }
}
