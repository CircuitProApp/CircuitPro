//
//  CanvasDragDropHandler.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit

final class CanvasDragDropHandler {
    unowned let controller: CanvasController

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Runs a given point through the controller's ordered pipeline of input processors.
    private func process(point: CGPoint, context: RenderContext) -> CGPoint {
        return controller.inputProcessors.reduce(point) { currentPoint, processor in
            processor.process(
                point: currentPoint,
                context: context,
                environment: controller.environment
            )
        }
    }

    func draggingEntered(_ sender: NSDraggingInfo, in host: CanvasHostView) -> NSDragOperation {
        let pboard = sender.draggingPasteboard

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

        controller.mouseLocation = rawPoint

        return .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?, in host: CanvasHostView) {
        controller.mouseLocation = nil
        controller.environment.processedMouseLocation = nil
    }

    func performDragOperation(_ sender: NSDraggingInfo, in host: CanvasHostView) -> Bool {

        let context = controller.currentContext(for: host.bounds, visibleRect: host.visibleRect)

        let rawPoint = host.convert(sender.draggingLocation, from: nil)

        let processedPoint = self.process(point: rawPoint, context: context)
        controller.mouseLocation = rawPoint
        controller.environment.processedMouseLocation = processedPoint

        let success = controller.onPasteboardDropped?(sender.draggingPasteboard, processedPoint) ?? false

        controller.mouseLocation = nil
        controller.environment.processedMouseLocation = nil

        return success
    }
}
