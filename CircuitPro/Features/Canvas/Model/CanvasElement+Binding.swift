//
//  CanvasElement+Binding.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

extension Binding where Value == CanvasElement {
    var pin: Binding<Pin>? {
        guard case .pin = self.wrappedValue else { return nil }
        return Binding<Pin>(
            get: {
                guard case .pin(let value) = self.wrappedValue else {
                    fatalError("Cannot get non-pin value as a Pin")
                }
                return value
            },
            set: {
                self.wrappedValue = .pin($0)
            }
        )
    }

    var primitive: Binding<AnyPrimitive>? {
        guard case .primitive = self.wrappedValue else { return nil }
        return Binding<AnyPrimitive>(
            get: {
                guard case .primitive(let value) = self.wrappedValue else {
                    fatalError("Cannot get non-primitive value as an AnyPrimitive")
                }
                return value
            },
            set: {
                self.wrappedValue = .primitive($0)
            }
        )
    }
    
    var pad: Binding<Pad>? {
        guard case .pad = self.wrappedValue else { return nil }
        return Binding<Pad>(
            get: {
                guard case .pad(let value) = self.wrappedValue else {
                    // This fatalError is for programmer-error, it should not happen in correct usage.
                    fatalError("Cannot get non-pad value as a Pad")
                }
                return value
            },
            set: {
                self.wrappedValue = .pad($0)
            }
        )
    }
    
}
