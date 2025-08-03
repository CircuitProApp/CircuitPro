//
//  NumericType.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI
/// A protocol that defines the requirements for a type to be used with NumericField.
/// It ensures the type supports basic arithmetic, comparison, and conversion from/to Double.
protocol NumericType: Numeric, Comparable {
    init(_ double: Double)
    var doubleValue: Double { get }
}

extension Double: NumericType { public var doubleValue: Double { self } }
extension Float: NumericType { public var doubleValue: Double { Double(self) } }
extension CGFloat: NumericType { public var doubleValue: Double { Double(self) } }
extension Int: NumericType { public var doubleValue: Double { Double(self) } }
