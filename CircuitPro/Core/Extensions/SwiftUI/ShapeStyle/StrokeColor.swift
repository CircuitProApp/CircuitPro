//
//  StrokeColor.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI

struct StrokeColor: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        if environment.colorScheme == .light {
            return Color.gray.mix(with: .white, by: 0.55)
        } else {
            return Color.gray.mix(with: .black, by: 0.45)
        }
    }
}

extension ShapeStyle where Self == StrokeColor {
    static var stroleColor: StrokeColor {
        .init()
    }
}
