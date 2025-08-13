//
//  TextAnchor.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

// Enum to represent the 9 anchor points
enum TextAnchor: Displayable {
    case topLeft, topCenter, topRight
    case middleLeading, middleCenter, middleTrailing
    case bottomLeft, bottomCenter, bottomRight
    
    var label: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .middleLeading: return "Middle Leading"
        case .middleCenter: return "Middle Center"
        case .middleTrailing: return "Middle Trailing"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        }
    }
}
