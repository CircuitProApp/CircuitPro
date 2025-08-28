//
//  TextAnchor.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

// Enum to represent the 9 anchor points
enum TextAnchor: Displayable {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing
    
    var label: String {
        switch self {
        case .topLeading: return "Top Leading"
        case .top: return "Top"
        case .topTrailing: return "Top Trailing"
        case .leading: return "Leading"
        case .center: return "Center"
        case .trailing: return "Trailing"
        case .bottomLeading: return "Bottom Leading"
        case .bottom: return "Bottom"
        case .bottomTrailing: return "Bottom Trailing"
        }
    }
}
