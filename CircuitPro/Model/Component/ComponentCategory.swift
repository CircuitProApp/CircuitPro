//
//  ComponentCategory.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/15/25.
//
import SwiftUI

enum ComponentCategory: String, Codable, CaseIterable, Identifiable {
    case passive
    case active
    case electromechanical
    case connector
    case power
    case analog
    case digital
    case rf
    case sensor
    case microcontroller
    case memory
    case display
    case oscillator
    case protection
    case miscellaneous

    var id: String { rawValue }

    var label: String {
        switch self {
        case .passive: return "Passive"
        case .active: return "Active"
        case .electromechanical: return "Electromechanical"
        case .connector: return "Connector"
        case .power: return "Power"
        case .analog: return "Analog"
        case .digital: return "Digital"
        case .rf: return "RF"
        case .sensor: return "Sensor"
        case .microcontroller: return "Microcontroller"
        case .memory: return "Memory"
        case .display: return "Display"
        case .oscillator: return "Oscillator"
        case .protection: return "Protection"
        case .miscellaneous: return "Miscellaneous"
        }
    }
}
