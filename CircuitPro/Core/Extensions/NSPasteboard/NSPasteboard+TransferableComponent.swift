//
//  NSPasteboard.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit
import UniformTypeIdentifiers

extension NSPasteboard.PasteboardType {
    static let transferableComponent = NSPasteboard.PasteboardType(UTType.transferableComponent.identifier)
}
