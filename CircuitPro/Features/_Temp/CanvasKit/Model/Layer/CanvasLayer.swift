//
//  CanvasLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/8/25.
//


// Features/_Temp/CanvasKit/Model/Layer/CanvasLayer.swift

import SwiftUI
import AppKit

/// Represents a distinct, user-manageable drawing layer within the canvas.
/// This is the primary data model for layers, distinct from `RenderLayer` which
/// handles rendering passes.
struct CanvasLayer: Identifiable, Hashable {
    let id: UUID
    var name: String
    var isVisible: Bool
    var color: CGColor
    var zIndex: Int
    
    // An optional, application-specific enum linking to your LayerKind.
    let kind: AnyHashable?
    
    init(id: UUID = UUID(), name: String, isVisible: Bool = true, color: CGColor, zIndex: Int, kind: AnyHashable? = nil) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.color = color
        self.zIndex = zIndex
        self.kind = kind
    }
}
