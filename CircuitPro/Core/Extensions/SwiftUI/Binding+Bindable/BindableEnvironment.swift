//
//  BindableEnvironment.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/29/25.
//

import SwiftUI
import Observation

@propertyWrapper
struct BindableEnvironment<Value>: DynamicProperty where Value: Observable & AnyObject {
    private var env: Environment<Value>

    // Support classic key-path environment values (rarely Observable)
    init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.env = Environment(keyPath)
    }

    // Support typed environment objects: @Environment(Value.self)
    init(_ type: Value.Type) {
        self.env = Environment(type)
    }

    var wrappedValue: Value {
        env.wrappedValue
    }

    // Enables `$myValue.someProperty` bindings (like @Bindable)
    var projectedValue: Bindable<Value> {
        Bindable(env.wrappedValue)
    }

    mutating func update() {
        env.update()
    }
}
