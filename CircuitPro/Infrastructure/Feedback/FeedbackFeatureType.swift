//
//  FeedbackFeatureType.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/11/25.
//

import SwiftUI

enum FeedbackFeatureType: Displayable {
    case schematicWire
    case navigatorView
    case componentDesign
    case libraryView
    
    var label: String {
        switch self {
        case .schematicWire: return "Schematic Wire"
        case .navigatorView: return "Navigator/Sidebar View"
        case .componentDesign: return "Component Design"
        case .libraryView: return "Library View"
        }
    }
}
