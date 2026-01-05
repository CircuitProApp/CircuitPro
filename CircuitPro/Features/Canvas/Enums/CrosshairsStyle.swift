//
//  CrosshairsStyle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

enum CrosshairsStyle: Displayable {
    case hidden
    case fullScreenLines
    case centeredCross

    var label: String {
        switch self {
        case .hidden:
            return "Hidden"
        case .fullScreenLines:
            return "Full Screen"
        case .centeredCross:
            return "Centered Cross"
        }
    }
}
