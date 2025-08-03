import AppKit
import UniformTypeIdentifiers

final class WorkbenchInputCoordinator {

    // MARK: - Dependencies
    unowned let host: CanvasHostView
    unowned let controller: CanvasController

    // MARK: - Gesture Helpers
    private lazy var rotation = RotationGestureController(controller: controller)
    private lazy var marquee = MarqueeSelectionGesture(controller: controller)
    private lazy var handleDrag = HandleDragGesture(controller: controller)
    private lazy var selDrag = SelectionDragGesture(controller: controller)
    private lazy var toolTap = ToolActionController(controller: controller, hitTestService: self)
    private lazy var keyCmds = WorkbenchKeyCommandController(controller: controller, coordinator: self)
    
    /// The gesture recogniser that currently owns the mouse drag.
    private var activeDrag: CanvasDragGesture?

    // MARK: - Init
    init(host: CanvasHostView, controller: CanvasController) {
        self.host = host
        self.controller = controller
    }

    // MARK: - Exposed State
    var isRotating: Bool { rotation.active }

    // MARK: - Keyboard Input
    func keyDown(_ event: NSEvent) -> Bool { keyCmds.handle(event) }

    // MARK: - Mouse Movement
    func mouseMoved(_ event: NSEvent) {
        let point = host.convert(event.locationInWindow, from: nil)

        // Update the controller's state
        let snappedPoint = controller.snap(point)
        controller.mouseLocation = snappedPoint
        
        // Let the rotation gesture update if active
        rotation.update(to: point)

        // Let the tool preview update
        // The preview layer will get the mouse location from the context
        
        // Trigger a redraw to show crosshairs, previews, etc.
        controller.redraw()
    }

    func mouseExited() {
        controller.mouseLocation = nil
        controller.redraw()
    }

    // MARK: - Mouse Clicks & Drags
    func mouseDown(_ event: NSEvent) {
        // First, check for and cancel any active rotation gesture.
        if rotation.active {
            rotation.cancel()
            controller.redraw()
            return
        }
        
        let point = host.convert(event.locationInWindow, from: nil)
        
        // If an active tool consumes the click, we're done.
        if toolTap.handleMouseDown(at: point, event: event) {
            controller.redraw()
            return
        }

        // Prioritize dragging a resize/edit handle.
        if handleDrag.begin(at: point, event: event) {
            activeDrag = handleDrag
            controller.redraw()
            return
        }

        // If cursor tool is active, handle selection and dragging.
        guard controller.selectedTool?.id == "cursor" else { return }
        
        // Does the click hit an existing element?
        if let hitTarget = self.hitTest(point: point) {
            
            let idToSelect = hitTarget.selectableID
            
            // Handle selection logic (Shift key for additive selection).
            if let hitID = idToSelect {
                if event.modifierFlags.contains(.shift) {
                    if controller.selectedIDs.contains(hitID) {
                        controller.selectedIDs.remove(hitID)
                    } else {
                        controller.selectedIDs.insert(hitID)
                    }
                } else {
                    // Only re-select if the item isn't already the sole selection.
                    if !(controller.selectedIDs.count == 1 && controller.selectedIDs.contains(hitID)) {
                        controller.selectedIDs = [hitID]
                    }
                }
            }

            // After updating selection, attempt to begin a drag.
            if selDrag.begin(at: point, with: hitTarget, event: event) {
                activeDrag = selDrag
            }
        // If the click hit empty space...
        } else {
            // Clear existing selection if not shift-clicking.
            if !event.modifierFlags.contains(.shift) && !controller.selectedIDs.isEmpty {
                controller.selectedIDs.removeAll()
            }
            // Begin marquee selection.
            marquee.begin(at: point, event: event)
        }
        
        controller.redraw()
    }

    func mouseDragged(_ event: NSEvent) {
        let point = host.convert(event.locationInWindow, from: nil)

        if marquee.active {
            marquee.drag(to: point)
        } else {
            activeDrag?.drag(to: point)
        }
        
        controller.redraw()
    }

    func mouseUp(_ event: NSEvent) {
        if marquee.active {
            marquee.end()
        }
        activeDrag?.end()
        activeDrag = nil
        controller.redraw()
    }

    // MARK: - Right Click for Context Menu
    func rightMouseDown(_ event: NSEvent) {
        guard controller.selectedTool?.id == "cursor" else { return }

        let point = host.convert(event.locationInWindow, from: nil)
        guard let hitTarget = self.hitTest(point: point),
              let hitID = hitTarget.selectableID else {
            return
        }

        // If the right-clicked item is not already selected, make it the selection.
        if !controller.selectedIDs.contains(hitID) {
            controller.selectedIDs = [hitID]
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
    
    // MARK: - Public Actions (called by key commands)
    func enterRotationMode(around point: CGPoint) {
        rotation.begin(at: point)
        controller.redraw()
    }
    
    func cancelRotation() {
        rotation.cancel()
        controller.redraw()
    }

    func handleReturnKeyPress() {
        guard var tool = controller.selectedTool else { return }

        let context = self.currentContext()
        let result = tool.handleReturn()
        switch result {
        case .element(let newElement):
            controller.elements.append(newElement)
            if case .primitive(let prim) = newElement {
                // controller.onPrimitiveAdded?(prim.id, context.selectedLayer)
            }
        case .schematicModified:
             controller.syncPinPositionsToGraph()
        case .noResult:
            break
        }
        controller.selectedTool = tool
        controller.redraw()
    }

    func deleteSelectedElements() {
        guard !controller.selectedIDs.isEmpty else { return }
        controller.schematicGraph.delete(items: controller.selectedIDs)
        controller.elements.removeAll { controller.selectedIDs.contains($0.id) }
        controller.selectedIDs.removeAll()
        controller.redraw()
    }

    // MARK: - Reset & Helpers
    func reset() {
        marquee.end()
        activeDrag?.end()
        activeDrag = nil
        rotation.cancel()
        controller.redraw()
    }

    func currentContext() -> RenderContext {
        return RenderContext(
            elements: controller.elements, schematicGraph: controller.schematicGraph,
            selectedIDs: controller.selectedIDs, marqueeSelectedIDs: controller.marqueeSelectedIDs,
            magnification: controller.magnification, selectedTool: controller.selectedTool,
            mouseLocation: controller.mouseLocation, marqueeRect: controller.marqueeRect,
            paperSize: controller.paperSize, sheetOrientation: controller.sheetOrientation,
            sheetCellValues: controller.sheetCellValues, snapGridSize: controller.snapGridSize,
            showGuides: controller.showGuides, crosshairsStyle: controller.crosshairsStyle,
            hostViewBounds: host.bounds
        )
    }
    
    // MARK: - Drag & Drop Destination
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadItem(withDataConformingToTypes: [UTType.transferableComponent.identifier]) {
            return .copy
        }
        return []
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadItem(withDataConformingToTypes: [UTType.transferableComponent.identifier]) {
            return .copy
        }
        return []
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let data = sender.draggingPasteboard.data(forType: .transferableComponent) else { return false }

        do {
            let component = try JSONDecoder().decode(TransferableComponent.self, from: data)
            let pointInView = host.convert(sender.draggingLocation, from: nil)

            // controller.onComponentDropped?(component, pointInView) // Add this callback to controller if needed
            host.window?.makeFirstResponder(host)
            return true
        } catch {
            print("Failed to decode TransferableComponent:", error)
            return false
        }
    }
}

// MARK: - Hit Test Service Conformance
extension WorkbenchInputCoordinator {
    func hitTest(point: CGPoint) -> CanvasHitTarget? {
        let context = self.currentContext()
        // Iterate through layers from top to bottom (visually)
        for layer in controller.renderLayers.reversed() {
            if let hit = layer.hitTest(point: point, context: context) {
                return hit
            }
        }
        return nil
    }
}
