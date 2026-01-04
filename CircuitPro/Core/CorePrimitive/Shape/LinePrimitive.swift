//
//  LinePrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import CoreGraphics

public struct LinePrimitive: Codable, Hashable {
    public var length: CGFloat

    public init(length: CGFloat) {
        self.length = length
    }
}
