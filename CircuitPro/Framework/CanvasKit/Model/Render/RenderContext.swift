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
    let magnification: CGFloat
    let mouseLocation: CGPoint?
    let selectedTool: CanvasTool?
    let highlightedItemIDs: Set<UUID>
    let selectedItemIDs: Set<UUID>
    let hostViewBounds: CGRect
    let visibleRect: CGRect

    let layers: [any CanvasLayer]

    /// The ID of the currently active layer, if any.
    let activeLayerId: UUID?

    let snapProvider: any SnapProvider
    let items: [any CanvasItem]

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

    init(magnification: CGFloat, mouseLocation: CGPoint?, selectedTool: CanvasTool?, highlightedItemIDs: Set<UUID>, selectedItemIDs: Set<UUID>, hostViewBounds: CGRect, visibleRect: CGRect, layers: [any CanvasLayer], activeLayerId: UUID?, snapProvider: any SnapProvider, items: [any CanvasItem], environment: CanvasEnvironmentValues, inputProcessors: [any InputProcessor]) {
        self.magnification = magnification
        self.mouseLocation = mouseLocation
        self.selectedTool = selectedTool
        self.highlightedItemIDs = highlightedItemIDs
        self.selectedItemIDs = selectedItemIDs
        self.hostViewBounds = hostViewBounds
        self.visibleRect = visibleRect
        self.layers = layers
        self.activeLayerId = activeLayerId
        self.snapProvider = snapProvider
        self.items = items
        self.environment = environment
        self.inputProcessors = inputProcessors
    }
}

extension RenderContext {
    var connectionAnchors: [any ConnectionAnchor] {
        items.compactMap { $0 as? any ConnectionAnchor }
    }

    var connectionPoints: [any ConnectionPoint] {
        items.compactMap { $0 as? any ConnectionPoint }
    }

    var connectionEdges: [any ConnectionEdge] {
        items.compactMap { $0 as? any ConnectionEdge }
    }

    var connectionAnchorPositionsByID: [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        positions.reserveCapacity(connectionAnchors.count)
        for anchor in connectionAnchors {
            positions[anchor.id] = anchor.position
        }
        return positions
    }
}
