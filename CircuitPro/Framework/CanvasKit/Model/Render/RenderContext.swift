//
//  RenderContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

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
    let visibleRect: CGRect

    let layers: [CanvasLayer]

    /// The ID of the currently active layer, if any.
    let activeLayerId: UUID?

    let snapProvider: any SnapProvider
    let graph: Graph?

    // MARK: - Extensible Application-Specific Data
    public let environment: CanvasEnvironmentValues

    private let inputProcessors: [any InputProcessor]


    var processedMouseLocation: CGPoint? {
        guard let location = mouseLocation else { return nil }

        // This is the same logic from CanvasInputHandler, now available to render layers.
        return inputProcessors.reduce(location) { currentPoint, processor in
            processor.process(point: currentPoint, context: self)
        }
    }

    init(sceneRoot: BaseNode, magnification: CGFloat, mouseLocation: CGPoint?, selectedTool: CanvasTool?, highlightedNodeIDs: Set<UUID>, hostViewBounds: CGRect, visibleRect: CGRect, layers: [CanvasLayer], activeLayerId: UUID?, snapProvider: any SnapProvider, graph: Graph?, environment: CanvasEnvironmentValues, inputProcessors: [any InputProcessor]) {
        self.sceneRoot = sceneRoot
        self.magnification = magnification
        self.mouseLocation = mouseLocation
        self.selectedTool = selectedTool
        self.highlightedNodeIDs = highlightedNodeIDs
        self.hostViewBounds = hostViewBounds
        self.visibleRect = visibleRect
        self.layers = layers
        self.activeLayerId = activeLayerId
        self.snapProvider = snapProvider
        self.graph = graph
        self.environment = environment
        self.inputProcessors = inputProcessors
    }
}
