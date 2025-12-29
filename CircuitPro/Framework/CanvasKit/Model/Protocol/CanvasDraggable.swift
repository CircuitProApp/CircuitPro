//
//  CanvasDraggable.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import CoreGraphics
import Foundation

/// A protocol for canvas items that can be dragged.
/// Conforming types provide their current position and can update it.
protocol CanvasDraggable: CanvasRenderable {
    /// The current world position of this item.
    var worldPosition: CGPoint { get }

    /// The current rotation of this item in radians.
    var worldRotation: CGFloat { get }

    /// Moves this item by the given delta.
    /// - Parameter delta: The amount to move in world coordinates.
    func move(by delta: CGPoint)
}

/// State for tracking a drag operation on CanvasDraggable items.
struct CanvasDragState {
    struct ItemState {
        let id: UUID
        let originalPosition: CGPoint
        let originalRotation: CGFloat
    }

    let origin: CGPoint
    let items: [ItemState]
    let wireEngine: WireEngine?
    let isAnchorDrag: Bool
}
