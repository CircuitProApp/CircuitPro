//
//  CirclePrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import CoreGraphics

public struct CirclePrimitive: Codable, Hashable {
    public var radius: CGFloat

    public init(radius: CGFloat) {
        self.radius = radius
    }
}
