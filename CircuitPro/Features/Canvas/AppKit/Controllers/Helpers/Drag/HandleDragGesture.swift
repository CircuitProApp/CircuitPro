import AppKit

final class HandleDragGesture: CanvasDragGesture {

    unowned let controller: CanvasController
    
    // The active handle being dragged (element ID, handle kind).
    private var active: (id: UUID, kind: Handle.Kind)?
    
    // The starting position of the opposite handle, if one exists, for proportional resizing.
    private var frozenOppositeHandlePosition: CGPoint?

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Checks if the user has clicked on an editable handle of the selected element.
    /// - Returns: `true` if a handle drag was successfully initiated.
    func begin(at point: CGPoint, event: NSEvent) -> Bool {
        // Handle dragging is only possible when a single element is selected.
        guard controller.selectedIDs.count == 1,
              let selectedID = controller.selectedIDs.first else {
            return false
        }
        
        // Find the selected element.
        guard let element = controller.elements.first(where: { $0.id == selectedID }),
              element.isPrimitiveEditable else {
            return false
        }
        
        // Use a dynamic tolerance based on zoom level to make handles easier to grab.
        let tolerance = 8.0 / controller.magnification

        // Check if the click point is within the tolerance of any of the element's handles.
        for handle in element.handles() {
            if hypot(point.x - handle.position.x, point.y - handle.position.y) < tolerance {
                // A handle was hit. Capture its state to begin the drag.
                active = (id: element.id, kind: handle.kind)
                
                // If the handle has a defined opposite, find and freeze its position.
                if let oppositeKind = handle.kind.opposite,
                   let oppositeHandle = element.handles().first(where: { $0.kind == oppositeKind }) {
                    frozenOppositeHandlePosition = oppositeHandle.position
                }
                
                return true
            }
        }
        
        // No handle was hit.
        return false
    }

    func drag(to point: CGPoint) {
        guard let active = self.active else { return }

        var updatedElements = controller.elements
        let snappedPoint = controller.snap(point)
        let snappedOpposite = frozenOppositeHandlePosition.map { controller.snap($0) }

        for i in updatedElements.indices where updatedElements[i].id == active.id {
            updatedElements[i].updateHandle(
                active.kind,
                to: snappedPoint,
                opposite: snappedOpposite
            )
            
            // Mutate the controller's state...
            controller.elements = updatedElements
            
            // And immediately inform SwiftUI of the change.
            controller.onUpdateElements?(updatedElements)
            
            return
        }
    }

    func end() {
        // Reset all transient state to finish the gesture.
        active = nil
        frozenOppositeHandlePosition = nil
    }
}
