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

extension TextAnchor {
    /// Calculates the coordinates of the anchor point within a given rectangle.
    func point(in rect: CGRect) -> CGPoint {
        let x: CGFloat
        let y: CGFloat

        switch self {
        case .topLeading:     x = rect.minX; y = rect.maxY
        case .top:            x = rect.midX; y = rect.maxY
        case .topTrailing:    x = rect.maxX; y = rect.maxY
        case .leading:        x = rect.minX; y = rect.midY
        case .center:         x = rect.midX; y = rect.midY
        case .trailing:       x = rect.maxX; y = rect.midY
        case .bottomLeading:  x = rect.minX; y = rect.minY
        case .bottom:         x = rect.midX; y = rect.minY
        case .bottomTrailing: x = rect.maxX; y = rect.minY
        }
        return CGPoint(x: x, y: y)
    }
}
