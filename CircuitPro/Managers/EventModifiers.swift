//
//  EventModifiers.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/21/25.

import AppKit
import SwiftUI

extension EventModifiers {
    init(from flags: NSEvent.ModifierFlags) {
        var result: EventModifiers = []

        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }

        self = result
    }
}
