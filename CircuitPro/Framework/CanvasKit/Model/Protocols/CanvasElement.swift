//
//  CanvasElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import AppKit

/// A type alias that composes all the core protocols required for an object
/// to be a fully interactive and renderable element on the canvas.
typealias CanvasElement =
    Transformable &
    Drawable &
    Hittable &
    Bounded &
    Hashable &
    Identifiable
