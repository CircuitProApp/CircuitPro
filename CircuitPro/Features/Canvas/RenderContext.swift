import AppKit

/// A snapshot of the canvas state, passed to each RenderLayer during a drawing pass.
/// This struct bundles all the information a layer might need to render itself.
struct RenderContext {
    // MARK: - Data Models
    
    /// The root of the scene graph containing all canvas nodes.
    let sceneRoot: any CanvasNode
    
    /// The data model for schematic nets and connections.
    let schematicGraph: SchematicGraph

    // MARK: - Visual State
    
    /// The unified set of all nodes that should be visually highlighted (e.g., with a halo).
    /// This combines the committed selection with any live marquee-hovered items.
    let highlightedNodeIDs: Set<UUID>
    
    /// The current zoom level of the canvas.
    let magnification: CGFloat
    
    /// The currently active tool (e.g., cursor, wire tool).
    let selectedTool: AnyCanvasTool?

    // MARK: - Interaction State
    
    /// The current position of the mouse, in world coordinates.
    let mouseLocation: CGPoint?
    
    /// The rectangle for the marquee selection tool, if currently active.
    let marqueeRect: CGRect?

    // MARK: - Configuration
    
    let paperSize: PaperSize
    let sheetOrientation: PaperOrientation
    let sheetCellValues: [String: String]
    let snapGridSize: CGFloat
    let showGuides: Bool
    let crosshairsStyle: CrosshairsStyle
    
    // MARK: - Geometry
    
    /// The bounds of the host view, in its own coordinate system.
    let hostViewBounds: CGRect
}

/// Defines a single, composable layer of rendering for the canvas.
/// Each rendering component conforms to this protocol.
protocol RenderLayer {
    /// A unique key for debugging and layer identification.
    var layerKey: String { get }
    
    /// Called once to create the permanent CALayer(s) for this renderer and add them
    /// as sublayers to the host's main layer.
    func install(on hostLayer: CALayer)
    
    /// Called on every redraw to update the properties (e.g., path, color, isHidden)
    /// of the layers this renderer installed previously.
    func update(using context: RenderContext)

    /// Performs a hit-test to determine if a point intersects with any interactive
    /// content managed by this layer.
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget?
}

// Default implementation makes hit-testing optional for layers that are not interactive.
extension RenderLayer {
    func hitTest(point: CGPoint, context: RenderContext) -> CanvasHitTarget? {
        return nil
    }
}
