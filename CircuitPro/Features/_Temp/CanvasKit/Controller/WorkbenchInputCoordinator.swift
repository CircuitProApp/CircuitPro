import AppKit
import UniformTypeIdentifiers

final class WorkbenchInputCoordinator {

    // MARK: - Dependencies
    unowned let host: CanvasHostView
    unowned let controller: CanvasController

    // MARK: - Gesture Helpers
    private lazy var rotation = RotationGestureController(controller: controller)
//    private lazy var marquee = MarqueeSelectionGesture(controller: controller)
//    private lazy var handleDrag = HandleDragGesture(controller: controller)
    private lazy var selDrag = SelectionDragGesture(controller: controller)
    // The ToolActionController is correctly initialized here.
    private lazy var toolTap = ToolActionController(controller: controller, coordinator: self)
    private lazy var keyCmds = WorkbenchKeyCommandController(controller: controller, coordinator: self)
    
    private var activeDrag: CanvasDragGesture?

    // MARK: - Init
    init(host: CanvasHostView, controller: CanvasController) {
        self.host = host
        self.controller = controller
    }

    // MARK: - State & Input (Largely Unchanged)
    var isRotating: Bool { rotation.active }
    func keyDown(_ event: NSEvent) -> Bool { keyCmds.handle(event) }
    func mouseExited() { controller.mouseLocation = nil; controller.redraw() }
    func mouseMoved(_ event: NSEvent) {
        let point = host.convert(event.locationInWindow, from: nil)
        controller.mouseLocation = controller.snap(point)
        rotation.update(to: point)
        controller.redraw()
    }

    // MARK: - Mouse Clicks & Drags (Corrected Logic)

    func mouseDown(_ event: NSEvent) {
        if rotation.active {
            rotation.commit()
            controller.redraw()
            return
        }
        
        let point = host.convert(event.locationInWindow, from: nil)
        let hitTarget = self.hitTest(point: point)
        
        // --- THIS IS THE FIX ---
        // First, see if the active tool wants to handle the mouse down event.
        // `handleMouseDown` returns `true` if it consumed the event (e.g., RectangleTool was active).
        // It returns `false` if the cursor was active, allowing the code below to run.
        if toolTap.handleMouseDown(at: point, hitTarget: hitTarget, event: event) {
            // The tool handled the event. We just need to redraw and exit.
            controller.redraw()
            return
        }
        
        // --- If we reach here, the cursor tool is active ---

        // Handle-related logic will be updated later.
        // if handleDrag.begin(...) { ... }
        
        if let hit = hitTarget {
            // Find the actual node that was hit in the scene graph.
            guard let hitID = hit.selectableID,
                  let nodeToSelect = findNode(with: hitID, in: controller.sceneRoot) else { return }

            // Handle selection logic with direct node references.
            if event.modifierFlags.contains(.shift) {
                if let index = controller.selectedNodes.firstIndex(where: { $0.id == nodeToSelect.id }) {
                    controller.selectedNodes.remove(at: index)
                } else {
                    controller.selectedNodes.append(nodeToSelect)
                }
            } else {
                if !(controller.selectedNodes.count == 1 && controller.selectedNodes.first?.id == nodeToSelect.id) {
                    controller.selectedNodes = [nodeToSelect]
                }
            }
            controller.onUpdateSelectedNodes?(controller.selectedNodes)

            // Begin dragging the now-updated selection.
            if selDrag.begin(at: point, with: hit, event: event) {
                activeDrag = selDrag
            }
            
        } else { // Clicked on empty space
            if !event.modifierFlags.contains(.shift) && !controller.selectedNodes.isEmpty {
                controller.selectedNodes.removeAll()
                controller.onUpdateSelectedNodes?(controller.selectedNodes)
            }
//            marquee.begin(at: point, event: event)
        }
        
        controller.redraw()
    }
    
    func mouseDragged(_ event: NSEvent) {
        let point = host.convert(event.locationInWindow, from: nil)
        activeDrag?.drag(to: point)
//        if marquee.active { marquee.drag(to: point) } else { activeDrag?.drag(to: point) }
        controller.redraw()
    }

    func mouseUp(_ event: NSEvent) {
//        if marquee.active { marquee.end() }
        activeDrag?.end()
        activeDrag = nil
        controller.redraw()
    }

    // MARK: - Right Click for Context Menu (Refactored)
    func rightMouseDown(_ event: NSEvent) {
        // This check is fine, as right-click menus should likely only work with the cursor.
        guard controller.selectedTool?.id == "cursor" else { return }

        let point = host.convert(event.locationInWindow, from: nil)
        guard let hitTarget = self.hitTest(point: point),
              let hitID = hitTarget.selectableID,
              let hitNode = findNode(with: hitID, in: controller.sceneRoot) else {
            return
        }

        if !controller.selectedNodes.contains(where: { $0.id == hitNode.id }) {
            controller.selectedNodes = [hitNode]
        }

        let menu = NSMenu()
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteMenuAction(_:)), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        if !menu.items.isEmpty {
            NSMenu.popUpContextMenu(menu, with: event, for: host)
        }
    }

    @objc private func deleteMenuAction(_ sender: Any) {
        deleteSelectedElements()
    }
    
    // MARK: - Public Actions (Refactored)
    
    func enterRotationMode(around point: CGPoint) {
        rotation.begin(around: point)
        controller.redraw()
    }
    
    func cancelRotation() {
        rotation.cancelAndRevert()
        controller.redraw()
    }

    func handleReturnKeyPress() {
        guard var tool = controller.selectedTool else { return }
        
        let result = tool.handleReturn()
        
        switch result {
        case .newNode(let newNode):
            controller.sceneRoot.addChild(newNode)
            controller.onNodesChanged?(controller.sceneRoot.children)
        case .schematicModified:
             // controller.syncPinPositionsToGraph() needs refactor
             break
        case .noResult:
            break
        }
        controller.selectedTool = tool
        controller.redraw()
    }

    func deleteSelectedElements() {
        guard !controller.selectedNodes.isEmpty else { return }
        
        let idsToDelete = Set(controller.selectedNodes.map { $0.id })
        
        // Remove from the scene graph
        for node in controller.selectedNodes {
            // controller.schematicGraph.delete(node: node) // To be updated
            node.removeFromParent()
        }
        
        // Notify the parent view of the change
        controller.onNodesChanged?(controller.sceneRoot.children)
        
        controller.selectedNodes.removeAll()
        controller.onUpdateSelectedNodes?([])
        controller.redraw()
    }

    // MARK: - Reset & Helpers

    func reset() {
//        marquee.end()
        activeDrag?.end()
        activeDrag = nil
        cancelRotation()
        controller.redraw()
    }

    func currentContext() -> RenderContext {
        return RenderContext(
            sceneRoot: controller.sceneRoot,
            schematicGraph: controller.schematicGraph,
            highlightedNodeIDs: controller.highlightedNodeIDs,
            magnification: controller.magnification,
            selectedTool: controller.selectedTool,
            mouseLocation: controller.mouseLocation,
            marqueeRect: controller.marqueeRect,
            paperSize: controller.paperSize,
            sheetOrientation: controller.sheetOrientation,
            sheetCellValues: controller.sheetCellValues,
            snapGridSize: controller.snapGridSize,
            showGuides: controller.showGuides,
            crosshairsStyle: controller.crosshairsStyle,
            hostViewBounds: host.bounds
        )
    }

    private func findNode(with id: UUID, in root: any CanvasNode) -> (any CanvasNode)? {
        if root.id == id {
            return root
        }
        for child in root.children {
            if let found = findNode(with: id, in: child) {
                return found
            }
        }
        return nil
    }
    
    // MARK: - Drag & Drop (Unchanged for now)
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { return [] }
    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { return [] }
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool { return false }
}

// MARK: - Hit Test Coordinator
extension WorkbenchInputCoordinator {
    func hitTest(point: CGPoint) -> CanvasHitTarget? {
        let context = self.currentContext()
        // Iterate reversed so we hit the top-most layer first.
        for layer in controller.renderLayers.reversed() {
            if let hit = layer.hitTest(point: point, context: context) {
                return hit
            }
        }
        return nil
    }
}
