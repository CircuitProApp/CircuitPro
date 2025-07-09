//
//  ComponentProperty.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/15/25.
//
import SwiftUI

struct ComponentProperty: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var key: PropertyKey?
    var value: PropertyValue
    var unit: Unit
    var warnsOnEdit: Bool = false
}

enum PropertyKey: Hashable, Codable, Identifiable {
    case basic(BasicType)
    case rating(RatingType)
    case temperature(TemperatureType)
    case rf(RFType)
    case battery(BatteryType)
    case sensor(SensorType)

    var id: String {
        switch self {
        case .basic(let type): return "basic.\(type.rawValue)"
        case .rating(let type): return "rating.\(type.rawValue)"
        case .temperature(let type): return "temp.\(type.rawValue)"
        case .rf(let type): return "rf.\(type.rawValue)"
        case .battery(let type): return "bat.\(type.rawValue)"
        case .sensor(let type): return "sensor.\(type.rawValue)"

        }
    }

    var label: String {
        switch self {
        case .basic(let type): return type.label
        case .rating(let type): return type.label
        case .temperature(let type): return type.label
        case .rf(let type): return type.label
        case .battery(let type): return type.label
        case .sensor(let type): return type.label
        }
    }

    enum BasicType: String, CaseIterable, Codable {
        case capacitance, resistance, inductance
        case voltage, current, power, frequency, tolerance

        var label: String {
            rawValue.capitalized
        }
    }

    enum RatingType: String, CaseIterable, Codable {
        case ratedVoltage, ratedCurrent, ratedPower, breakdownVoltage

        var label: String {
            switch self {
            case .ratedVoltage: return "Rated Voltage"
            case .ratedCurrent: return "Rated Current"
            case .ratedPower: return "Rated Power"
            case .breakdownVoltage: return "Breakdown Voltage"
            }
        }
    }

    enum TemperatureType: String, CaseIterable, Codable {
        case operating, storage, caseTemp

        var label: String {
            switch self {
            case .operating: return "Operating Temperature"
            case .storage: return "Storage Temperature"
            case .caseTemp: return "Case Temperature"
            }
        }
    }

    enum RFType: String, CaseIterable, Codable {
        case impedance, insertionLoss, returnLoss, VSWR

        var label: String {
            switch self {
            case .impedance: return "Impedance"
            case .insertionLoss: return "Insertion Loss"
            case .returnLoss: return "Return Loss"
            case .VSWR: return "VSWR"
            }
        }
    }

    enum BatteryType: String, CaseIterable, Codable {
        case capacity, energy, internalResistance

        var label: String {
            switch self {
            case .internalResistance: return "Internal Resistance"
            default: return rawValue.capitalized
            }
        }
    }

    enum SensorType: String, CaseIterable, Codable {
        case sensitivity, offsetVoltage, hysteresis

        var label: String {
            switch self {
            case .offsetVoltage: return "Offset Voltage"
            default: return rawValue.capitalized
            }
        }
    }
}

extension PropertyKey {
    var allowedValueType: PropertyValueType {
        switch self {
        case .temperature:
            return .range
        default:
            return .single
        }
    }
}

extension PropertyKey {
    var allowedBaseUnits: [BaseUnit] {
        switch self {
        // BASIC
        case .basic(let type):
            switch type {
            case .capacitance: return [.farad]
            case .resistance:  return [.ohm]
            case .inductance:  return [.henry]
            case .voltage:     return [.volt]
            case .current:     return [.ampere]
            case .power:       return [.watt]
            case .frequency:   return [.hertz]
            case .tolerance:   return [.percent]
            }

        // RATING
        case .rating(let type):
            switch type {
            case .ratedVoltage, .breakdownVoltage: return [.volt]
            case .ratedCurrent: return [.ampere]
            case .ratedPower: return [.watt]
            }

        // TEMPERATURE
        case .temperature:
            return [.celsius]

        // RF
        case .rf(let type):
            switch type {
            case .impedance: return [.ohm]
            case .insertionLoss, .returnLoss: return [.decibel]
            case .VSWR: return [] // Unitless or special formatting
            }

        // BATTERY
        case .battery(let type):
            switch type {
            case .capacity: return [.ampereHour]
            case .energy: return [.wattHour]
            case .internalResistance: return [.ohm]
            }

        // SENSOR
        case .sensor(let type):
            switch type {
            case .sensitivity: return [] // Disabled for now
            case .offsetVoltage: return [.volt]
            case .hysteresis: return [.celsius]
            }
        }
    }
}

enum PropertyValue: Codable, Equatable {
    case single(Double?)
    case range(min: Double?, max: Double?)

    var type: PropertyValueType {
        switch self {
        case .single: return .single
        case .range: return .range
        }
    }

    var description: String {
        switch self {
        case .single(let value):
            if let value { return "\(value)" } else { return "" }
        case let .range(min, max):
            return "\(min ?? 0) to \(max ?? 0)"
        }
    }

    // — Codable remains the same but modified for optionals —
    private enum CodingKeys: String, CodingKey {
        case type, value, min, max
    }

    private enum ValueType: String, Codable {
        case single, range
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)

        switch type {
        case .single:
            let value = try container.decodeIfPresent(Double.self, forKey: .value)
            self = .single(value)
        case .range:
            let min = try container.decodeIfPresent(Double.self, forKey: .min)
            let max = try container.decodeIfPresent(Double.self, forKey: .max)
            self = .range(min: min, max: max)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .single(let value):
            try container.encode(ValueType.single, forKey: .type)
            try container.encodeIfPresent(value, forKey: .value)
        case let .range(min, max):
            try container.encode(ValueType.range, forKey: .type)
            try container.encodeIfPresent(min, forKey: .min)
            try container.encodeIfPresent(max, forKey: .max)
        }
    }
}

enum PropertyValueType: String, CaseIterable, Identifiable, Codable {
    case single
    case range

    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: return "Single Value"
        case .range: return "Range"
        }
    }
}
