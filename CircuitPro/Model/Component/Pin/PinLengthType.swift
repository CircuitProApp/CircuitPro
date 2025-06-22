//
//  PinLengthType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

enum PinLengthType: Displayable {
    case short
    case long

    var label: String {
        switch self {
        case .short: return "Short"
        case .long: return "Long"
        }
    }
}
