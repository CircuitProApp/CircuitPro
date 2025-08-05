import AppKit

/// A snapshot of the canvas state, passed to each RenderLayer during a drawing pass.
/// This struct bundles all the information a layer might need to render itself.
struct RenderContext {
    // MARK: - Core Framework Data
    let sceneRoot: BaseNode
    let magnification: CGFloat
    let mouseLocation: CGPoint?
    let selectedTool: CanvasTool?
    let highlightedNodeIDs: Set<UUID>
    let hostViewBounds: CGRect

    // MARK: - Extensible Application-Specific Data
    public let environment: CanvasEnvironmentValues
}
