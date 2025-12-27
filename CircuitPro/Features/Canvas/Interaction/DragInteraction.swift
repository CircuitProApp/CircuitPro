import AppKit

/// Handles dragging selected nodes on the canvas.
/// This interaction can handle normal drags, wire drags via the `WireEngine`, and special
/// anchor-repositioning drags for text nodes when the Control key is held.
final class DragInteraction: CanvasInteraction {

    private struct DraggingState {
        let origin: CGPoint
        let originalNodePositions: [UUID: CGPoint]
        let graph: WireEngine?
    }

    private struct GraphDraggingState {
        let origin: CGPoint
        let originalPrimitives: [NodeID: AnyCanvasPrimitive]
        let originalTexts: [NodeID: GraphTextComponent]
        let ownedTextIDs: Set<NodeID>
        let originalPins: [NodeID: GraphPinComponent]
        let ownedPinIDs: Set<NodeID>
        let originalPads: [NodeID: GraphPadComponent]
        let ownedPadIDs: Set<NodeID>
        let originalSymbols: [NodeID: GraphSymbolComponent]
        let originalFootprints: [NodeID: GraphFootprintComponent]
        let ownerIDs: Set<UUID>
        let isAnchorDrag: Bool
        let wireEngine: WireEngine?
    }

    private var state: DraggingState?
    private var graphState: GraphDraggingState?
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0

    var wantsRawInput: Bool { true }

    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        self.state = nil
        self.graphState = nil
        guard controller.selectedTool is CursorTool else { return false }
        let tolerance = 5.0 / context.magnification

        if controller.selectedNodes.isEmpty, let graph = context.graph {
            if let graphHit = GraphHitTester().hitTest(point: point, context: context, scope: .graphOnly),
               graph.selection.contains(graphHit) {
                let hitPrimitive = graph.component(AnyCanvasPrimitive.self, for: graphHit) != nil
                let hitText = graph.component(GraphTextComponent.self, for: graphHit) != nil
                let hitPin = graph.component(GraphPinComponent.self, for: graphHit)
                let hitPad = graph.component(GraphPadComponent.self, for: graphHit)
                let hitSymbol = graph.component(GraphSymbolComponent.self, for: graphHit) != nil
                let hitFootprint = graph.component(GraphFootprintComponent.self, for: graphHit) != nil
                let hitSelectablePin = hitPin?.isSelectable ?? false
                let hitSelectablePad = hitPad?.isSelectable ?? false
                if hitPrimitive || hitText || hitSelectablePin || hitSelectablePad || hitSymbol || hitFootprint {
                    let selectedIDs = graph.selection
                    var originalPrimitives: [NodeID: AnyCanvasPrimitive] = [:]
                    var originalTexts: [NodeID: GraphTextComponent] = [:]
                    var originalPins: [NodeID: GraphPinComponent] = [:]
                    var originalPads: [NodeID: GraphPadComponent] = [:]
                    var originalSymbols: [NodeID: GraphSymbolComponent] = [:]
                    var originalFootprints: [NodeID: GraphFootprintComponent] = [:]
                    var ownerIDs = Set<UUID>()
                    for id in selectedIDs {
                        if let original = graph.component(AnyCanvasPrimitive.self, for: id) {
                            originalPrimitives[id] = original
                        }
                        if let original = graph.component(GraphTextComponent.self, for: id) {
                            originalTexts[id] = original
                        }
                        if let original = graph.component(GraphPinComponent.self, for: id), original.isSelectable {
                            originalPins[id] = original
                        }
                        if let original = graph.component(GraphPadComponent.self, for: id), original.isSelectable {
                            originalPads[id] = original
                        }
                        if let original = graph.component(GraphSymbolComponent.self, for: id) {
                            originalSymbols[id] = original
                            ownerIDs.insert(original.ownerID)
                        }
                        if let original = graph.component(GraphFootprintComponent.self, for: id) {
                            originalFootprints[id] = original
                            ownerIDs.insert(original.ownerID)
                        }
                    }

                    let ownedTextIDs = Set(graph.components(GraphTextComponent.self).compactMap { id, component in
                        ownerIDs.contains(component.ownerID) ? id : nil
                    })
                    let ownedPinIDs = Set<NodeID>(graph.components(GraphPinComponent.self).compactMap { id, component in
                        guard let ownerID = component.ownerID else { return nil }
                        return ownerIDs.contains(ownerID) ? id : nil
                    })
                    let ownedPadIDs = Set<NodeID>(graph.components(GraphPadComponent.self).compactMap { id, component in
                        guard let ownerID = component.ownerID else { return nil }
                        return ownerIDs.contains(ownerID) ? id : nil
                    })

                    for id in ownedTextIDs {
                        if originalTexts[id] == nil, let original = graph.component(GraphTextComponent.self, for: id) {
                            originalTexts[id] = original
                        }
                    }
                    for id in ownedPinIDs {
                        if originalPins[id] == nil, let original = graph.component(GraphPinComponent.self, for: id) {
                            originalPins[id] = original
                        }
                    }
                    for id in ownedPadIDs {
                        if originalPads[id] == nil, let original = graph.component(GraphPadComponent.self, for: id) {
                            originalPads[id] = original
                        }
                    }

                    var activeWireEngine: WireEngine?
                    if let wireEngine = context.environment.wireEngine, !ownerIDs.isEmpty {
                        let selectedRawIDs = Set(selectedIDs.map { $0.rawValue })
                        if wireEngine.beginDrag(selectedIDs: selectedRawIDs) {
                            activeWireEngine = wireEngine
                        }
                    }
                    let isAnchorDrag = event.modifierFlags.contains(.control)
                    self.graphState = GraphDraggingState(
                        origin: point,
                        originalPrimitives: originalPrimitives,
                        originalTexts: originalTexts,
                        ownedTextIDs: ownedTextIDs,
                        originalPins: originalPins,
                        ownedPinIDs: ownedPinIDs,
                        originalPads: originalPads,
                        ownedPadIDs: ownedPadIDs,
                        originalSymbols: originalSymbols,
                        originalFootprints: originalFootprints,
                        ownerIDs: ownerIDs,
                        isAnchorDrag: isAnchorDrag,
                        wireEngine: activeWireEngine
                    )
                    self.didMove = false
                    return true
                }
            }

            if let wireEngine = context.environment.wireEngine,
               let graphHit = GraphHitTester().hitTest(point: point, context: context, scope: .graphOnly),
               graph.selection.contains(graphHit),
               graph.component(WireEdgeComponent.self, for: graphHit) != nil {
                if wireEngine.beginDrag(selectedIDs: Set(graph.selection.map { $0.rawValue })) {
                    self.state = DraggingState(origin: point, originalNodePositions: [:], graph: wireEngine)
                    self.didMove = false
                    return true
                }
            }
            return false
        }

        guard !controller.selectedNodes.isEmpty else { return false }
        guard let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) else { return false }
        var nodeToDrag: BaseNode? = hit.node
        var hitNodeIsSelected = false
        while let currentNode = nodeToDrag {
            if controller.selectedNodes.contains(where: { $0.id == currentNode.id }) {
                hitNodeIsSelected = true
                break
            }
            nodeToDrag = currentNode.parent
        }
        guard hitNodeIsSelected else { return false }
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes {
            if node is Transformable {
                originalPositions[node.id] = node.position
            }
        }

        if let wireEngine = context.environment.wireEngine {
            let nodeSelection = Set(controller.selectedNodes.map { $0.id })
            let graphSelection = Set(context.graph?.selection.map { $0.rawValue } ?? [])
            let selectedIDs = nodeSelection.union(graphSelection)
            if wireEngine.beginDrag(selectedIDs: selectedIDs) {
                self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: wireEngine)
            } else {
                self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: nil)
            }
        } else {
            self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: nil)
        }

        self.didMove = false
        return true
    }

    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        if let currentGraphState = graphState, let graph = context.graph {
            let rawDelta = CGVector(dx: point.x - currentGraphState.origin.x, dy: point.y - currentGraphState.origin.y)
            if !didMove {
                if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
                didMove = true
            }
            let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
            let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)
            var ownerStates: [UUID: (position: CGPoint, rotation: CGFloat)] = [:]
            for (id, original) in currentGraphState.originalSymbols {
                var updated = original
                updated.position = original.position + deltaPoint
                graph.setComponent(updated, for: id)
                ownerStates[original.ownerID] = (updated.position, updated.rotation)
            }
            for (id, original) in currentGraphState.originalFootprints {
                var updated = original
                updated.position = original.position + deltaPoint
                graph.setComponent(updated, for: id)
                ownerStates[original.ownerID] = (updated.position, updated.rotation)
            }
            for (id, original) in currentGraphState.originalPrimitives {
                var updated = original
                updated.position = original.position + deltaPoint
                graph.setComponent(updated, for: id)
            }
            for (id, original) in currentGraphState.originalTexts {
                if currentGraphState.ownedTextIDs.contains(id),
                   let ownerState = ownerStates[original.ownerID] {
                    var updated = original
                    updated.ownerPosition = ownerState.position
                    updated.ownerRotation = ownerState.rotation
                    let ownerTransform = CGAffineTransform(translationX: ownerState.position.x, y: ownerState.position.y)
                        .rotated(by: ownerState.rotation)
                    updated.worldPosition = updated.resolvedText.relativePosition.applying(ownerTransform)
                    updated.worldAnchorPosition = updated.resolvedText.anchorPosition.applying(ownerTransform)
                    updated.worldRotation = ownerState.rotation + updated.resolvedText.cardinalRotation.radians
                    graph.setComponent(updated, for: id)
                    continue
                }

                var updated = original
                updated.worldPosition = original.worldPosition + deltaPoint
                let inverseOwner = original.ownerTransform.inverted()
                updated.resolvedText.relativePosition = updated.worldPosition.applying(inverseOwner)
                if currentGraphState.isAnchorDrag {
                    updated.worldAnchorPosition = original.worldAnchorPosition + deltaPoint
                    updated.resolvedText.anchorPosition = updated.worldAnchorPosition.applying(inverseOwner)
                }
                graph.setComponent(updated, for: id)
            }
            for (id, original) in currentGraphState.originalPins {
                if currentGraphState.ownedPinIDs.contains(id),
                   let ownerID = original.ownerID,
                   let ownerState = ownerStates[ownerID] {
                    var updated = original
                    updated.ownerPosition = ownerState.position
                    updated.ownerRotation = ownerState.rotation
                    graph.setComponent(updated, for: id)
                } else {
                    var updated = original
                    let worldPosition = original.pin.position.applying(original.ownerTransform)
                    let newWorldPosition = worldPosition + deltaPoint
                    updated.pin.position = newWorldPosition.applying(original.ownerTransform.inverted())
                    graph.setComponent(updated, for: id)
                }
            }
            for (id, original) in currentGraphState.originalPads {
                if currentGraphState.ownedPadIDs.contains(id),
                   let ownerID = original.ownerID,
                   let ownerState = ownerStates[ownerID] {
                    var updated = original
                    updated.ownerPosition = ownerState.position
                    updated.ownerRotation = ownerState.rotation
                    graph.setComponent(updated, for: id)
                } else {
                    var updated = original
                    let worldPosition = original.pad.position.applying(original.ownerTransform)
                    let newWorldPosition = worldPosition + deltaPoint
                    updated.pad.position = newWorldPosition.applying(original.ownerTransform.inverted())
                    graph.setComponent(updated, for: id)
                }
            }
            currentGraphState.wireEngine?.updateDrag(by: deltaPoint)
            return
        }

        guard let currentState = self.state else { return }

        let rawDelta = CGVector(dx: point.x - currentState.origin.x, dy: point.y - currentState.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }
        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)
        for node in controller.selectedNodes {
            if let originalPosition = currentState.originalNodePositions[node.id] {
                node.position = originalPosition + deltaPoint
                if let primitiveNode = node as? PrimitiveNode, let graph = context.graph {
                    graph.setComponent(primitiveNode.primitive, for: NodeID(primitiveNode.id))
                }
            }
        }

        if let graph = currentState.graph {
            graph.updateDrag(by: deltaPoint)
        }


    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if let currentGraphState = graphState {
            currentGraphState.wireEngine?.endDrag()
            self.graphState = nil
            didMove = false
            return
        }
        if let graph = self.state?.graph {
            graph.endDrag()
        }

        self.state = nil
        self.didMove = false
    }
}
