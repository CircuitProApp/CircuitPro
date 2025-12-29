//
//  ConnectionEngine.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import CoreGraphics
import Foundation

/// A domain-agnostic protocol for connection/linking systems on the canvas.
///
/// CanvasKit uses this to support dragging connected items while maintaining
/// their relationships. Domain-specific implementations (e.g., WireEngine for
/// circuits, FlowConnectionEngine for flowcharts) conform to this protocol.
protocol ConnectionEngine: AnyObject {

    /// Begins a drag operation for the selected items.
    /// - Parameter selectedIDs: IDs of the items being dragged.
    /// - Returns: true if the engine will handle connection updates during drag.
    func beginDrag(selectedIDs: Set<UUID>) -> Bool

    /// Updates the ongoing drag operation.
    /// - Parameter delta: The movement delta from the drag origin.
    func updateDrag(by delta: CGPoint)

    /// Ends the current drag operation.
    func endDrag()
}
