import CoreGraphics

final class CanvasMarqueeDragState {
    var origin: CGPoint?
    var isAdditive: Bool = false

    func begin(origin: CGPoint, isAdditive: Bool) {
        self.origin = origin
        self.isAdditive = isAdditive
    }

    func reset() {
        origin = nil
        isAdditive = false
    }
}

private struct CanvasMarqueeDragStateKey: CanvasEnvironmentKey {
    static var defaultValue: CanvasMarqueeDragState { CanvasMarqueeDragState() }
}

extension CanvasEnvironmentValues {
    var marqueeDragState: CanvasMarqueeDragState {
        get { self[CanvasMarqueeDragStateKey.self] }
        set { self[CanvasMarqueeDragStateKey.self] = newValue }
    }
}
