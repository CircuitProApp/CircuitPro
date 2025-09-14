//
//  NSPasteboard.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit
import UniformTypeIdentifiers

extension NSPasteboard.PasteboardType {
    
    /// The pasteboard type for dragging a new component definition from a library.
    static let transferableComponent = NSPasteboard.PasteboardType(UTType.transferableComponent.identifier)
    
    /// The pasteboard type for dragging an existing, unplaced component instance to the canvas.
    static let transferablePlacement = NSPasteboard.PasteboardType(UTType.transferablePlacement.identifier)
}
