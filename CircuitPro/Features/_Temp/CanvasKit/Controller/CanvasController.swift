import AppKit

/// A lean, generic controller that manages the universal state and pipelines of a canvas instance.
@Observable
final class CanvasController {
    // Core data model
    let sceneRoot: any CanvasNode = BaseNode()
    var selectedNodes: [any CanvasNode] = []
    
    // Universal view state
    var magnification: CGFloat = 1.0
    var mouseLocation: CGPoint?
    var selectedTool: AnyCanvasTool?

    // Pluggable pipelines defined by the user of the framework.
    var renderLayers: [RenderLayer] = []
    var interactions: [any CanvasInteraction] = []

    // Callbacks to SwiftUI
    var onNeedsRedraw: (() -> Void)?
    var onUpdateSelectedNodes: (([any CanvasNode]) -> Void)?
    var onNodesChanged: (([any CanvasNode]) -> Void)?

    func redraw() {
        onNeedsRedraw?()
    }
}
