//
//  RenderContext.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit

/// A snapshot of the canvas state, passed to each CK render layer during a drawing pass.
/// This struct bundles all the information a layer might need to render itself.
struct RenderContext {
    // MARK: - Core Framework Data
    let magnification: CGFloat
    let mouseLocation: CGPoint?
    let selectedTool: CanvasTool?
    let highlightedItemIDs: Set<UUID>
    let selectedItemIDs: Set<UUID>
    let highlightedLinkIDs: Set<UUID>
    let canvasBounds: CGRect
    let visibleRect: CGRect

    let layers: [any CanvasLayer]

    /// The ID of the currently active layer, if any.
    let activeLayerId: UUID?

    let snapProvider: any SnapProvider
    let items: [any CanvasItem]
    let hitTargets: HitTargetRegistry
    let hitTestDepth: Int
    let hitTestTransform: CGAffineTransform

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

    init(magnification: CGFloat, mouseLocation: CGPoint?, selectedTool: CanvasTool?, highlightedItemIDs: Set<UUID>, selectedItemIDs: Set<UUID>, highlightedLinkIDs: Set<UUID>, hostViewBounds: CGRect, visibleRect: CGRect, layers: [any CanvasLayer], activeLayerId: UUID?, snapProvider: any SnapProvider, items: [any CanvasItem], environment: CanvasEnvironmentValues, inputProcessors: [any InputProcessor], hitTargets: HitTargetRegistry, hitTestDepth: Int = 0, hitTestTransform: CGAffineTransform = .identity) {
        self.magnification = magnification
        self.mouseLocation = mouseLocation
        self.selectedTool = selectedTool
        self.highlightedItemIDs = highlightedItemIDs
        self.selectedItemIDs = selectedItemIDs
        self.highlightedLinkIDs = highlightedLinkIDs
        self.canvasBounds = hostViewBounds
        self.visibleRect = visibleRect
        self.layers = layers
        self.activeLayerId = activeLayerId
        self.snapProvider = snapProvider
        self.items = items
        self.environment = environment
        self.inputProcessors = inputProcessors
        self.hitTargets = hitTargets
        self.hitTestDepth = hitTestDepth
        self.hitTestTransform = hitTestTransform
    }
}

extension RenderContext {
    func withHitTestDepth(_ depth: Int) -> RenderContext {
        RenderContext(
            magnification: magnification,
            mouseLocation: mouseLocation,
            selectedTool: selectedTool,
            highlightedItemIDs: highlightedItemIDs,
            selectedItemIDs: selectedItemIDs,
            highlightedLinkIDs: highlightedLinkIDs,
            hostViewBounds: canvasBounds,
            visibleRect: visibleRect,
            layers: layers,
            activeLayerId: activeLayerId,
            snapProvider: snapProvider,
            items: items,
            environment: environment,
            inputProcessors: inputProcessors,
            hitTargets: hitTargets,
            hitTestDepth: depth,
            hitTestTransform: hitTestTransform
        )
    }

    func withHitTestTransform(_ transform: CGAffineTransform) -> RenderContext {
        RenderContext(
            magnification: magnification,
            mouseLocation: mouseLocation,
            selectedTool: selectedTool,
            highlightedItemIDs: highlightedItemIDs,
            selectedItemIDs: selectedItemIDs,
            highlightedLinkIDs: highlightedLinkIDs,
            hostViewBounds: canvasBounds,
            visibleRect: visibleRect,
            layers: layers,
            activeLayerId: activeLayerId,
            snapProvider: snapProvider,
            items: items,
            environment: environment,
            inputProcessors: inputProcessors,
            hitTargets: hitTargets,
            hitTestDepth: hitTestDepth,
            hitTestTransform: hitTestTransform.concatenating(transform)
        )
    }
}

extension RenderContext {
    var connectionEngine: (any ConnectionEngine)? {
        environment.connectionEngine
    }

    var connectionPoints: [any ConnectionPoint] {
        items.compactMap { $0 as? any ConnectionPoint }
    }

    var connectionLinks: [any ConnectionLink] {
        items.compactMap { $0 as? any ConnectionLink }
    }

    var connectionPointPositionsByID: [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        positions.reserveCapacity(connectionPoints.count)
        for point in connectionPoints {
            positions[point.id] = point.position
        }
        return positions
    }
}
