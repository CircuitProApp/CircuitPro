//
//  RenderContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import AppKit

/// A snapshot of the canvas state, passed to each RenderLayer during a drawing pass.
/// This struct bundles all the information a layer might need to render itself.
struct RenderContext {
    // Data
    let elements: [CanvasElement]
    let schematicGraph: SchematicGraph

    // View State
    let selectedIDs: Set<UUID>
    let marqueeSelectedIDs: Set<UUID>
    let magnification: CGFloat
    let selectedTool: AnyCanvasTool?

    // Interaction State
    let mouseLocation: CGPoint?
    let marqueeRect: CGRect?

    // Configuration
    let paperSize: PaperSize
    let sheetOrientation: PaperOrientation
    let sheetCellValues: [String: String]
    let snapGridSize: CGFloat
    let showGuides: Bool
    let crosshairsStyle: CrosshairsStyle
    
    // Geometry
    let hostViewBounds: CGRect
}

/// Defines a single, composable layer of rendering for the canvas.
/// Each rendering component conforms to this protocol.
protocol RenderLayer {
    /// A unique key for debugging and potential future caching.
    var layerKey: String { get }

    /// Generates the CALayers for this rendering pass based on the provided context.
    /// - Parameter context: The current state of the canvas.
    /// - Returns: An array of CALayers to be displayed for this layer.
    func makeLayers(context: RenderContext) -> [CALayer]
    
    /// Performs a hit-test on the contents of this layer.
    /// - Parameter point: The point to test in world coordinates.
    /// - Parameter context: The current state of the canvas.
    /// - Returns: A hit-test result if the point intersects an object on this layer.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget?
}

// Default implementation makes hit-testing optional for layers that are not interactive.
extension RenderLayer {
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
}
