//
//  AnyPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import Foundation

public enum AnyPrimitive: Codable, Hashable {
    case line(LinePrimitive)
    case rectangle(RectanglePrimitive)
    case circle(CirclePrimitive)
}
