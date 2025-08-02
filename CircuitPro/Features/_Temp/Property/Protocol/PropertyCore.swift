//
//  PropertyCore.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

/// Defines the essential, shared fields that constitute the core of any property.
/// This enables writing generic functions that can operate on any property-like object.
protocol PropertyCore {
    /// The property key (e.g., Resistance, Tolerance), which is typically immutable.
    var key: PropertyKey { get }
    
    /// The property's value, which is mutable.
    var value: PropertyValue { get set }
    
    /// The property's unit, which is typically immutable.
    var unit: Unit { get }
}
