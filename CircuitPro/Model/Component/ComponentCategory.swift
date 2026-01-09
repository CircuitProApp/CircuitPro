//
//  ComponentCategory.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/15/25.
//
import SwiftUI

enum ComponentCategory: Displayable {
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
    
    // TODO: Assign colors properly
    var color: Color {
        switch self {
        case .passive:
                .red
        case .active:
                .orange
        case .electromechanical:
                .yellow
        case .connector:
                .green
        case .power:
                .teal
        case .analog:
                .mint
        case .digital:
                .blue
        case .rf:
                .red
        case .sensor:
                .purple
        case .microcontroller:
                .gray
        case .memory:
                .pink
        case .display:
                .cyan
        case .oscillator:
                .indigo
        case .protection:
                .blue
        case .miscellaneous:
                .purple
        }
    }
}
