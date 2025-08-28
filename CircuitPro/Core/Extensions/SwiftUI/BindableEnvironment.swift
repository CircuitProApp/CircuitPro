//
//  BindableEnvironment.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/29/25.
//

import SwiftUI

@propertyWrapper
struct BindableEnvironment<Value>: DynamicProperty where Value: Observable & AnyObject {
    private var env: Environment<Value>

    init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.env = Environment(keyPath)
    }

    var wrappedValue: Value {
        env.wrappedValue
    }

    // This is what gives you `$value.property` bindings just like `@Bindable`.
    var projectedValue: Bindable<Value> {
        Bindable(wrappedValue: env.wrappedValue)
    }

    mutating func update() {
        env.update()
    }
}
