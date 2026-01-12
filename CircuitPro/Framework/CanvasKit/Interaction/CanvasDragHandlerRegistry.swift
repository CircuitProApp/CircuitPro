import AppKit

struct CanvasGlobalDragEvent {
    let event: NSEvent
    let rawLocation: CGPoint
    let processedLocation: CGPoint
    let rawDelta: CGPoint
    let processedDelta: CGPoint
}

enum CanvasGlobalDragPhase {
    case began(CanvasGlobalDragEvent)
    case changed(CanvasGlobalDragEvent)
    case ended(CanvasGlobalDragEvent)
}

struct CanvasGlobalDragHandler {
    let id: UUID
    let handler: (CanvasGlobalDragPhase, RenderContext, CanvasController) -> Void
}

final class CanvasDragHandlerRegistry {
    private(set) var handlers: [CanvasGlobalDragHandler] = []

    func reset() {
        handlers.removeAll(keepingCapacity: true)
    }

    func add(_ handler: CanvasGlobalDragHandler) {
        handlers.append(handler)
    }

    func handle(_ phase: CanvasGlobalDragPhase, context: RenderContext, controller: CanvasController) {
        for handler in handlers {
            handler.handler(phase, context, controller)
        }
    }
}
