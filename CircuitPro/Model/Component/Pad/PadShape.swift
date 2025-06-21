//
//  PadShape.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/5/25.
//

import SwiftUI

enum PadShape: Codable, Hashable {

    case rect(width: Double, height: Double)
    case circle(radius: Double)

    private enum CodingKeys: String, CodingKey {
        case type, width, height, radius
    }

    private enum ShapeType: String, Codable {
        case rect, circle
    }

    // Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let shapeType = try container.decode(ShapeType.self, forKey: .type)

        switch shapeType {
        case .rect:
            let width = try container.decode(Double.self, forKey: .width)
            let height = try container.decode(Double.self, forKey: .height)
            self = .rect(width: width, height: height)
        case .circle:
            let radius = try container.decode(Double.self, forKey: .radius)
            self = .circle(radius: radius)
        }
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .rect(width, height):
            try container.encode(ShapeType.rect, forKey: .type)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
        case .circle(let radius):
            try container.encode(ShapeType.circle, forKey: .type)
            try container.encode(radius, forKey: .radius)
        }
    }
}
