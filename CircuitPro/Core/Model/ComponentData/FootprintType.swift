//
//  FootprintType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/17/25.
//

import SwiftUI

enum FootprintType: String, Displayable {
    case throughHole
    case surfaceMount
    case socketed

    var label: String {
        switch self {
        case .throughHole: return "Through-Hole"
        case .surfaceMount: return "Surface Mount"
        case .socketed: return "Socketed"
        }
    }
}
