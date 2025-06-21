//
//  PadType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/5/25.
//

import SwiftUI

enum PadType: Displayable {

    case surfaceMount
    case throughHole

    var label: String {
        switch self {
        case .surfaceMount:
            return "Surface Mount"
        case .throughHole:
            return "Through Hole"
        }
    }
}
