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
    let sceneRoot: any CanvasNode
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
    
    func count(where predicate: (CanvasElement) -> Bool) -> Int {
        return 0 /*elements.lazy.filter(predicate).count*/
    }
}

/// Defines a single, composable layer of rendering for the canvas.
/// Each rendering component conforms to this protocol.
protocol RenderLayer {
    /// A unique key for debugging and layer identification.
    var layerKey: String { get }
    
    /// CALayer(s) and adds them as sublayers to the host's main layer.
    func install(on hostLayer: CALayer)
    
    /// (path, color, isHidden, etc.) of the layers it installed previously.
    func update(using context: RenderContext)

    /// Hit-testing logic remains the same.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget?
}

// Default implementation makes hit-testing optional for layers that are not interactive.
extension RenderLayer {
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
}
