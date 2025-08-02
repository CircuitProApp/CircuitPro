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
    
    var text: Binding<TextElement>? {
        guard case .text = self.wrappedValue else { return nil }
        return Binding<TextElement>(
            get: {
                guard case .text(let value) = self.wrappedValue else {
                    fatalError("Cannot get non-text value as a TextElement")
                }
                return value
            },
            set: {
                self.wrappedValue = .text($0)
            }
        )
    }
    
}

//
//  CanvasElement+Helpers.swift
//  CircuitPro
//
//  Created by Gemini on 28.07.25.
//

import Foundation

extension CanvasElement {
    
    /// Provides safe, optional access to the underlying `TextElement` if the
    /// canvas element is of the `.text` case.
    ///
    /// Returns `nil` for all other cases.
    var asTextElement: TextElement? {
        get {
            guard case .text(let textElement) = self else { return nil }
            return textElement
        }
        set {
            // If the new value is not nil, update self to be a .text case.
            // If the new value is nil, this will effectively do nothing,
            // which is often the desired behavior for a computed property setter.
            if let newValue {
                self = .text(newValue)
            }
        }
    }
    
    /// Provides safe, optional access to the underlying `Pin` if the
    /// canvas element is of the `.pin` case.
    var asPin: Pin? {
        get {
            guard case .pin(let pin) = self else { return nil }
            return pin
        }
        set {
            if let newValue {
                self = .pin(newValue)
            }
        }
    }
    
    /// Provides safe, optional access to the underlying `AnyPrimitive` if the
    /// canvas element is of the `.primitive` case.
    var asPrimitive: AnyPrimitive? {
        get {
            guard case .primitive(let primitive) = self else { return nil }
            return primitive
        }
        set {
            if let newValue {
                self = .primitive(newValue)
            }
        }
    }
    
    /// Provides safe, optional access to the underlying `Pad` if the
    /// canvas element is of the `.pad` case.
    var asPad: Pad? {
        get {
            guard case .pad(let pad) = self else { return nil }
            return pad
        }
        set {
            if let newValue {
                self = .pad(newValue)
            }
        }
    }
}
