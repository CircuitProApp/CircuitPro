import SwiftUI

enum SIPrefix: String, CaseIterable, Codable {
    case none  = "-"
    case pico  = "p"
    case nano  = "n"
    case micro = "μ"
    case milli = "m"
    case kilo  = "k"
    case mega  = "M"
    case giga  = "G"

    var symbol: String { rawValue }

    var name: String {
        switch self {
        case .none:  return "-"
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

struct Unit: CustomStringConvertible, Codable {
    var prefix: SIPrefix
    var base: BaseUnit?

    var symbol: String {
        guard let base = base else { return prefix.symbol }
        return "\(prefix.symbol)\(base.symbol)"
    }

    var name: String {
        guard let base = base else { return prefix.name }
        let prefixString = prefix == .none ? "" : prefix.name
        return [prefixString, base.name].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var description: String { symbol }

    init(prefix: SIPrefix = .none, base: BaseUnit? = nil) {
        if let base = base, !base.allowsPrefix && prefix != .none {
            fatalError("Invalid prefix for base unit.")
        }
        self.prefix = prefix
        self.base = base
    }
}
