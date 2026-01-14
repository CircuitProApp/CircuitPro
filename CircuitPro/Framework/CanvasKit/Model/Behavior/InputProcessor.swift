//
//  InputProcessor.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import CoreGraphics

/// Defines a module that can intercept and process a coordinate within the canvas
/// before it is passed to interactions.
///
/// Input Processors are executed as an ordered pipeline, where the output of one
/// processor is the input to the next. This allows for composable behaviors
/// like snapping, angle locking, or guide alignment.
protocol InputProcessor {
    /// Processes a single point based on the current canvas context.
    ///
    /// - Parameters:
    ///   - point: The input point to be processed. This may be the raw mouse location
    ///            or the result of a previous processor in the pipeline.
    ///   - context: The complete render context at the moment of the event.
    ///   - environment: The environment snapshot for configuration like snapping or themes.
    /// - Returns: The processed `CGPoint` that will be passed to the next processor
    ///            or to the interactions if this is the last one.
    func process(
        point: CGPoint,
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> CGPoint
}
