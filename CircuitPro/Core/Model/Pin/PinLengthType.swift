//
//  PinLengthType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

enum PinLengthType: Displayable {
    case extraShort
    case short
    case regular
    case long
    case extraLong

    var label: String {
        switch self {
        case .extraShort: return "Extra Short"
        case .short: return "Short"
        case .regular: return "Regular"
        case .long: return "Long"
        case .extraLong: return "Extra Long"
        }
    }

    var cgFloatValue: CGFloat {
        switch self {
        case .extraShort: return 30.0
        case .short: return 40.0
        case .regular: return 50.0
        case .long: return 60.0
        case .extraLong: return 70.0
        }
    }
}
