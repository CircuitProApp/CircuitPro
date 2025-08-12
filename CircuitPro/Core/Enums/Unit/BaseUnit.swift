//
//  BaseUnit.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

enum BaseUnit: String, CaseIterable, Codable {
    case ohm     = "Ω"
    case farad   = "F"
    case henry   = "H"
    case volt    = "V"
    case ampere  = "A"
    case watt    = "W"
    case hertz   = "Hz"
    case celsius = "°C"
    case percent = "%"
    case ampereHour = "Ah"
    case wattHour   = "Wh"
    case decibel    = "dB"

    var symbol: String { rawValue }

    var name: String {
        switch self {
        case .ohm:     return "Ohm"
        case .farad:   return "Farad"
        case .henry:   return "Henry"
        case .volt:    return "Volt"
        case .ampere:  return "Ampere"
        case .watt:    return "Watt"
        case .hertz:   return "Hertz"
        case .celsius: return "Celsius"
        case .percent: return "Percent"
        case .ampereHour: return "Ampere Hour"
        case .wattHour:   return "Watt Hour"
        case .decibel:    return "Decibel"
        }
    }

    var allowsPrefix: Bool {
          switch self {
          case .percent, .celsius, .decibel:
              return false
          default:
              return true
          }
      }
}
