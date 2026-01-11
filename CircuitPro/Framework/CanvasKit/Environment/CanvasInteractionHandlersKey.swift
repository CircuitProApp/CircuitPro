import Foundation

private struct CanvasHoverHandlerKey: CanvasEnvironmentKey {
    static let defaultValue: ((UUID, Bool) -> Void)? = nil
}

private struct CanvasTapHandlerKey: CanvasEnvironmentKey {
    static let defaultValue: ((UUID) -> Void)? = nil
}

private struct CanvasDragHandlerKey: CanvasEnvironmentKey {
    static let defaultValue: ((UUID, CanvasDragPhase) -> Void)? = nil
}

extension CanvasEnvironmentValues {
    var onHoverItem: ((UUID, Bool) -> Void)? {
        get { self[CanvasHoverHandlerKey.self] }
        set { self[CanvasHoverHandlerKey.self] = newValue }
    }

    var onTapItem: ((UUID) -> Void)? {
        get { self[CanvasTapHandlerKey.self] }
        set { self[CanvasTapHandlerKey.self] = newValue }
    }

    var onDragItem: ((UUID, CanvasDragPhase) -> Void)? {
        get { self[CanvasDragHandlerKey.self] }
        set { self[CanvasDragHandlerKey.self] = newValue }
    }

    func withHoverHandler(_ handler: ((UUID, Bool) -> Void)?) -> CanvasEnvironmentValues {
        var copy = self
        copy.onHoverItem = handler
        return copy
    }

    func withTapHandler(_ handler: ((UUID) -> Void)?) -> CanvasEnvironmentValues {
        var copy = self
        copy.onTapItem = handler
        return copy
    }

    func withDragHandler(_ handler: ((UUID, CanvasDragPhase) -> Void)?) -> CanvasEnvironmentValues {
        var copy = self
        copy.onDragItem = handler
        return copy
    }
}
