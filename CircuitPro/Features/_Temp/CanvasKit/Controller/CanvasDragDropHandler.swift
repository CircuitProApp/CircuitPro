//
//  CanvasDragDropHandler.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

// Features/_Temp/CanvasKit/Controller/CanvasDragDropHandler.swift
import AppKit

final class CanvasDragDropHandler {
    unowned let controller: CanvasController

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Runs a given point through the controller's ordered pipeline of input processors.
    private func process(point: CGPoint, context: RenderContext) -> CGPoint {
        return controller.inputProcessors.reduce(point) { currentPoint, processor in
            processor.process(point: currentPoint, context: context)
        }
    }

    func draggingEntered(_ sender: NSDraggingInfo, in host: CanvasHostView) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        // We read the registered types directly from the host view.
        let registeredTypeIdentifiers = host.registeredDraggedTypes.map { $0.rawValue }
        
        guard let pasteboardTypes = pboard.types,
              pasteboardTypes.contains(where: { registeredTypeIdentifiers.contains($0.rawValue) })
        else {
            return []
        }
        
        return .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo, in host: CanvasHostView) -> NSDragOperation {
        let rawPoint = host.convert(sender.draggingLocation, from: nil)

        // Storing the RAW mouse location is correct for previews.
        // Render layers get the processed version from the context if they need it.
        controller.mouseLocation = rawPoint
        controller.redraw()
        
        return .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?, in host: CanvasHostView) {
        // Clear the mouse location to remove any visual drop previews.
        controller.mouseLocation = nil
        controller.redraw()
    }

    func performDragOperation(_ sender: NSDraggingInfo, in host: CanvasHostView) -> Bool {
        // --- THIS IS THE FIX ---

        // 1. Get the current render context to access input processors.
        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)
        
        // 2. Get the raw, unprocessed drop location.
        let rawPoint = host.convert(sender.draggingLocation, from: nil)

        // 3. Process the point through the pipeline (e.g., snap it to the grid).
        let processedPoint = self.process(point: rawPoint, context: context)
        
        // 4. Use the final, PROCESSED point for the drop callback.
        let success = controller.onPasteboardDropped?(sender.draggingPasteboard, processedPoint) ?? false
        
        // 5. Clean up any visual artifacts from the drag.
        controller.mouseLocation = nil
        controller.redraw()
        
        return success
    }
}
