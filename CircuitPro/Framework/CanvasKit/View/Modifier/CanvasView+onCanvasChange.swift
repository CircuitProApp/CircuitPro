//
//  CanvasView+onCanvasChange.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import AppKit

extension CanvasView {
    /// Registers a callback to be invoked whenever the canvas's view state changes,
    /// such as when the mouse moves or the visible area scrolls.
    func onCanvasChange(_ perform: @escaping (CanvasChangeContext) -> Void) -> CanvasView {
        var view = self
        view.onCanvasChange = perform
        return view
    }
}
