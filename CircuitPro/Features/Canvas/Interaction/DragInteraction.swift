import AppKit

/// Handles dragging selected nodes on the canvas.
/// This interaction can handle normal drags, wire drags via the `WireGraph`, and special
/// anchor-repositioning drags for text nodes when the Control key is held.
final class DragInteraction: CanvasInteraction {

    private struct DraggingState {
        let origin: CGPoint
        let originalNodePositions: [UUID: CGPoint]
        let graph: WireGraph?
        let isAnchorDrag: Bool
        let originalAnchorPositions: [UUID: CGPoint]
    }

    private struct GraphDraggingState {
        let origin: CGPoint
        let originalPrimitives: [NodeID: AnyCanvasPrimitive]
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
            if let graphHit = GraphHitTester().hitTest(point: point, context: context),
               graph.selection.contains(graphHit),
               let primitive = graph.component(AnyCanvasPrimitive.self, for: graphHit) {
                let selectedIDs = graph.selection
                var originals: [NodeID: AnyCanvasPrimitive] = [:]
                for id in selectedIDs {
                    if let original = graph.component(AnyCanvasPrimitive.self, for: id) {
                        originals[id] = original
                    }
                }
                self.graphState = GraphDraggingState(origin: point, originalPrimitives: originals)
                self.didMove = false
                return true
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
        let isAnchorDrag = event.modifierFlags.contains(.control)
        var originalAnchorPositions: [UUID: CGPoint] = [:]
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes {
            if node is Transformable {
                originalPositions[node.id] = node.position
            }
            if isAnchorDrag, let textNode = node as? AnchoredTextNode {
                originalAnchorPositions[node.id] = textNode.anchorPosition
            }
        }

        // Prime pin vertices for selected symbols so beginDrag has something to move
        if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
            for node in controller.selectedNodes {
                if let sym = node as? SymbolNode, let symbolDef = sym.instance.definition {
                    graphNode.graph.syncPins(for: sym.instance, of: symbolDef, ownerID: sym.id)
                }
            }

            // Now try to activate graph drag
            let selectedIDs = Set(controller.selectedNodes.map { $0.id })
            if graphNode.graph.beginDrag(selectedIDs: selectedIDs) {
                self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: graphNode.graph, isAnchorDrag: isAnchorDrag, originalAnchorPositions: originalAnchorPositions)
            } else {
                self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: nil, isAnchorDrag: isAnchorDrag, originalAnchorPositions: originalAnchorPositions)
            }
        } else {
            self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: nil, isAnchorDrag: isAnchorDrag, originalAnchorPositions: originalAnchorPositions)
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
            for (id, original) in currentGraphState.originalPrimitives {
                var updated = original
                updated.position = original.position + deltaPoint
                graph.setComponent(updated, for: id)
            }
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
        if currentState.isAnchorDrag {
            for node in controller.selectedNodes {
                guard let textNode = node as? AnchoredTextNode else { continue }
                if let originalPosition = currentState.originalNodePositions[textNode.id] {
                    textNode.position = originalPosition + deltaPoint
                }
                if let originalAnchorPos = currentState.originalAnchorPositions[textNode.id] {
                    textNode.anchorPosition = originalAnchorPos + deltaPoint
                }
            }
        } else {
            for node in controller.selectedNodes {
                if let originalPosition = currentState.originalNodePositions[node.id] {
                    node.position = originalPosition + deltaPoint
                    if let primitiveNode = node as? PrimitiveNode, let graph = context.graph {
                        graph.setComponent(primitiveNode.primitive, for: NodeID(primitiveNode.id))
                    }
                }
            }
        }

        if let graph = currentState.graph {
            graph.updateDrag(by: deltaPoint)
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                graphNode.syncChildNodesFromModel()
            }
        } else {
            // Fallback: graph drag not active, do live pin sync for moved symbols
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                for node in controller.selectedNodes {
                    // --- UPDATED LOGIC ---
                    // Apply the same fix here for consistency.
                    if let sym = node as? SymbolNode, let symbolDef = sym.instance.definition {
                        // The node's position has already been updated, so its instance is up-to-date.
                        graphNode.graph.syncPins(for: sym.instance, of: symbolDef, ownerID: sym.id)
                    }
                }
                graphNode.syncChildNodesFromModel()
            }
        }


    }

    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if graphState != nil {
            graphState = nil
            didMove = false
            return
        }
        if let graph = self.state?.graph {
            graph.endDrag()
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                graphNode.syncChildNodesFromModel()
            }
        }

        if didMove {
            for node in controller.selectedNodes {
                if let textNode = node as? AnchoredTextNode {
                    textNode.commitChanges()
                }
            }
        }

        self.state = nil
        self.didMove = false
    }
}
