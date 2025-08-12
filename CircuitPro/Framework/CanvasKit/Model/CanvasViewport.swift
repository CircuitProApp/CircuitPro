//
//  CanvasViewport.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI

/// A struct that encapsulates the state of the canvas viewport, including its
/// size, magnification level, and the currently visible rectangle.
struct CanvasViewport: Equatable {
    /// The size of the canvas's document view.
    var size: CGSize
    
    /// The magnification (zoom level) of the canvas. 1.0 is 100%.
    var magnification: CGFloat = 1.0
    
    /// The portion of the document view that is currently visible in the scroll view's clip view.
    /// This property allows for both reading the current scroll position and programmatically changing it.
    var visibleRect: CGRect
    
    
    /// A special sentinel value used to indicate that the viewport should
    /// be automatically centered on its first appearance.
    public static let autoCenter = CGRect(x: -1, y: -1, width: 0, height: 0)

    /// Creates a default viewport configuration that will auto-center itself.
    /// - Parameter size: The total size of the document that will be displayed.
    public static func centered(documentSize: CGSize) -> CanvasViewport {
        return CanvasViewport(
            size: documentSize,
            magnification: 1.0,
            visibleRect: self.autoCenter // Use the special value
        )
    }
}
