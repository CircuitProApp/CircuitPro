import AppKit


/// Handles dragging selected nodes on the canvas.
/// This interaction has special logic to handle dragging schematic wire via the `WireGraph` model.
final class DragInteraction: CanvasInteraction {
    
    private struct DraggingState {
        let origin: CGPoint
        let originalNodePositions: [UUID: CGPoint]
        let graph: WireGraph?
    }
    
    private var state: DraggingState?
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0
    
    var wantsRawInput: Bool { true }
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        self.state = nil
        guard controller.selectedTool is CursorTool, !controller.selectedNodes.isEmpty else { return false }

        let tolerance = 5.0 / context.magnification
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

        // Capture original positions of transformable nodes
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes where node is Transformable {
            originalPositions[node.id] = node.position
        }

        // Prime pin vertices for selected symbols so beginDrag has something to move
        if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
            for node in controller.selectedNodes {
                if let sym = node as? SymbolNode {
                    // Create a temporary instance with the node’s current position
                    var inst = sym.instance
                    inst.position = node.position   // ensure instance uses current visual position
                    graphNode.graph.syncPins(for: inst, of: sym.symbol, ownerID: sym.id)
                }
            }

            // Now try to activate graph drag
            let selectedIDs = Set(controller.selectedNodes.map { $0.id })
            if graphNode.graph.beginDrag(selectedIDs: selectedIDs) {
                self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: graphNode.graph)
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
        guard let currentState = self.state else { return }

        let rawDelta = CGVector(dx: point.x - currentState.origin.x, dy: point.y - currentState.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }

        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)

        // Move selected scene nodes visually
        for node in controller.selectedNodes {
            if let originalPosition = currentState.originalNodePositions[node.id] {
                node.position = originalPosition + deltaPoint
            }
        }

        if let graph = currentState.graph {
            // Graph drag is active: move pin vertices and edges together
            graph.updateDrag(by: deltaPoint)

            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                graphNode.syncChildNodesFromModel()
            }
        } else {
            // Fallback: graph drag not active, do live pin sync for moved symbols
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                for node in controller.selectedNodes {
                    if let sym = node as? SymbolNode {
                        var inst = sym.instance
                        inst.position = node.position  // current visual position
                        graphNode.graph.syncPins(for: inst, of: sym.symbol, ownerID: sym.id)
                    }
                }
                graphNode.syncChildNodesFromModel()
            }
        }

        controller.redraw()
    }
    
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if let graph = self.state?.graph {
            graph.endDrag()
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                // Final sync after normalization.
                graphNode.syncChildNodesFromModel()
            }
        }
        
        if didMove {
            // Persist changes for any nodes that were moved.
            for node in controller.selectedNodes {
                // If the dragged node is an anchored text, tell it to commit its
                // state back to its owning SymbolInstance model.
                if let textNode = node as? AnchoredTextNode {
                    textNode.commitChanges()
                }
            }
            
            // Notify the document that the model has changed and needs saving.
            controller.onModelDidChange?()
        }
        
        self.state = nil
        self.didMove = false
    }
}
