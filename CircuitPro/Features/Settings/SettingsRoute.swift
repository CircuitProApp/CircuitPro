//
//  SettingsRoute.swift
//  CircuitPro
//
//  Created by George Tchelidze on 1/10/26.
//

import SwiftUI

enum SettingsRoute: Displayable {
    case appearance

    var label: String {
        switch self {
        case .appearance: return "Appearance"
        }
    }

    var iconName: String {
        switch self {
        case .appearance: return "paintbrush"
        }
    }

    var iconColor: Color {
        switch self {
        case .appearance: return .blue
        }
    }
}
