//
//  CanvasElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import AppKit

/// A type alias that composes all the core protocols required for an object
/// to be a fully interactive and renderable element on the canvas.
///
/// By using a type alias, we gain the convenience of a single name (`CanvasElement`)
/// while retaining the flexibility of small, focused protocols. This allows other parts
/// of the system to depend only on the behaviors they need (e.g., just `Drawable`).
typealias CanvasElement =
    Transformable &
    Drawable &
    Hittable &
    Bounded &
    Hashable &
    Identifiable
