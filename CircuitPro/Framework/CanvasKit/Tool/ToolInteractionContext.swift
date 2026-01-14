//
//  ToolInteractionContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import AppKit

/// Contains all information related to a specific user interaction event for a tool.
struct ToolInteractionContext {
    /// The number of consecutive clicks for this event (e.g., for double-click detection).
    let clickCount: Int

    /// A reference to the full rendering context, providing the tool with access
    /// to the overall state of the canvas if needed.
    let renderContext: RenderContext
    let environment: CanvasEnvironmentValues

    var activeLayerId: UUID? {
        renderContext.activeLayerId
    }
}
