//
//  CanvasChangeContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI

/// A context object providing information about the canvas's state during a change event.
struct CanvasChangeContext {
    /// The raw location of the mouse cursor in the host view's coordinate space.
    let rawMouseLocation: CGPoint?
    
    /// The location of the mouse cursor after being processed by all `InputProcessor`s (e.g., snapped to grid).
    let processedMouseLocation: CGPoint?
    
    /// The currently visible portion of the canvas document, in the document's coordinate space.
    let visibleRect: CGRect
}
