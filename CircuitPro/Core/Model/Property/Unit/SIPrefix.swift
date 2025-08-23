//
//  SIPrefix.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

enum SIPrefix: String, CaseIterable, Codable, Identifiable {
    case pico  = "p"
    case nano  = "n"
    case micro = "μ"
    case milli = "m"
    case kilo  = "k"
    case mega  = "M"
    case giga  = "G"

    var symbol: String { rawValue }
    
    var id: String { rawValue }

    var name: String {
        switch self {
        case .pico:  return "pico"
        case .nano:  return "nano"
        case .micro: return "micro"
        case .milli: return "milli"
        case .kilo:  return "kilo"
        case .mega:  return "mega"
        case .giga:  return "giga"
        }
    }
}
