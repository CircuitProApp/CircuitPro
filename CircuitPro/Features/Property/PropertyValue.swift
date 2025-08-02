//
//  PropertyValue.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import Foundation

enum PropertyValue: Codable, Equatable, Hashable {
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
