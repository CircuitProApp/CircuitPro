import AppKit

/// Handles dragging selected nodes on the canvas.
/// This interaction can handle normal drags, wire drags via the `WireGraph`, and special
/// anchor-repositioning drags for text nodes when the Control key is held.
final class DragInteraction: CanvasInteraction {
    
    private struct DraggingState {
        let origin: CGPoint
        let originalNodePositions: [UUID: CGPoint]
        let graph: WireGraph?
        
        // --- NEW PROPERTIES ---
        /// True if the user is holding Control to drag the text anchor.
        let isAnchorDrag: Bool
        /// Stores the original anchor positions for text nodes during an anchor drag.
        let originalAnchorPositions: [UUID: CGPoint]
    }
    
    private var state: DraggingState?
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0
    
    var wantsRawInput: Bool { true }
    
    // MODIFIED: Signature updated to accept `NSEvent`.
    func mouseDown(with event: NSEvent, at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
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

        // --- NEW LOGIC for Anchor Drag ---
        let isAnchorDrag = event.modifierFlags.contains(.control)
        var originalAnchorPositions: [UUID: CGPoint] = [:]
        
        // Capture original positions of all transformable nodes.
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes {
            if node is Transformable {
                originalPositions[node.id] = node.position
            }
            // If this is an anchor drag, also capture the starting anchor positions for text nodes.
            if isAnchorDrag, let textNode = node as? AnchoredTextNode {
                originalAnchorPositions[node.id] = textNode.anchorPosition
            }
        }

        // Prime pin vertices for selected symbols so beginDrag has something to move
        if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
            for node in controller.selectedNodes {
                if let sym = node as? SymbolNode {
                    var inst = sym.instance
                    inst.position = node.position
                    graphNode.graph.syncPins(for: inst, of: sym.symbol, ownerID: sym.id)
                }
            }

            // Now try to activate graph drag
            let selectedIDs = Set(controller.selectedNodes.map { $0.id })
            if graphNode.graph.beginDrag(selectedIDs: selectedIDs) {
                // MODIFIED: Pass new state to DraggingState initializer
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
        guard let currentState = self.state else { return }

        let rawDelta = CGVector(dx: point.x - currentState.origin.x, dy: point.y - currentState.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }

        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)

        // --- MODIFIED: Split logic for normal drag vs. anchor drag ---
        if currentState.isAnchorDrag {
            // Anchor Drag (Control key is held): Move both text and its anchor together.
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
            // Normal Drag: Move only the nodes' main positions.
            for node in controller.selectedNodes {
                if let originalPosition = currentState.originalNodePositions[node.id] {
                    node.position = originalPosition + deltaPoint
                }
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
    
    // NOTE: This method requires no changes. The existing `commitChanges()` call is sufficient,
    // as it will read the modified `anchorPosition` from the node and persist it.
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
                // state back to its owning SymbolInstance model. This will correctly
                // save the newly modified `anchorPosition`.
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
