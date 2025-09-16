//
//  Binding+Extensions.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import SwiftUI

extension Binding {
    /// Creates a binding to an optional value from a binding to a non-optional value.
    ///
    /// This is useful when a generic framework component requires a `Binding<Value?>`
    /// but the application's specific data model uses a non-optional `Value`.
    ///
    /// - Parameter defaultValue: The value to set on the source binding when the
    ///   optional binding is set to `nil`.
    /// - Returns: A new binding to an optional value.
    func unwrapping(withDefault defaultValue: Value) -> Binding<Value?> {
        return Binding<Value?>(
            get: {
                // The get is simple: just return the non-optional value.
                // Swift automatically promotes it to an optional.
                return self.wrappedValue
            },
            set: { newValue in
                // The set is where the logic lives.
                if let value = newValue {
                    // If we received a real value, pass it through.
                    self.wrappedValue = value
                } else {
                    // If we received nil, set the source to our required default value.
                    self.wrappedValue = defaultValue
                }
            }
        )
    }
}
