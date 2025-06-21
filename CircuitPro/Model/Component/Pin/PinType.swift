//
//  PinType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

enum PinType: Displayable {

    case input
    case output
    case bidirectional
    case power
    case ground
    case passive
    case analog
    case clock
    case notConnected
    case unknown

    var label: String {
        switch self {
        case .input: return "Input"
        case .output: return "Output"
        case .bidirectional: return "Bidirectional"
        case .power: return "Power"
        case .ground: return "Ground"
        case .passive: return "Passive"
        case .analog: return "Analog"
        case .clock: return "Clock"
        case .notConnected: return "Not Connected"
        case .unknown: return "Unknown"
        }
    }
}
