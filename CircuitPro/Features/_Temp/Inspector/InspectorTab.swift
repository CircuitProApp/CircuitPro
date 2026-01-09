//
//  InspectorTab.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import Foundation

enum InspectorTab: SidebarTab {
    case attributes
    case appearance

    var label: String {
        switch self {
        case .attributes:
            return "Attributes"
        case .appearance:
            return "Appearance"
        }
    }
    
    var iconName: String {
        switch self {
        case .attributes:
            return "slider.horizontal.3"
        case .appearance:
            return "paintpalette"
        }
    }
}
