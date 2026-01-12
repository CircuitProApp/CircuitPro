import CoreGraphics
import Foundation

final class CanvasHandleDragState {
    private struct Key: Hashable {
        let ownerID: UUID
        let kind: CanvasHandle.Kind
    }

    private struct Session {
        let oppositeWorld: CGPoint
    }

    private var sessions: [Key: Session] = [:]

    func begin(ownerID: UUID, kind: CanvasHandle.Kind, oppositeWorld: CGPoint) {
        sessions[Key(ownerID: ownerID, kind: kind)] = Session(oppositeWorld: oppositeWorld)
    }

    func oppositeWorld(ownerID: UUID, kind: CanvasHandle.Kind) -> CGPoint? {
        sessions[Key(ownerID: ownerID, kind: kind)]?.oppositeWorld
    }

    func end(ownerID: UUID, kind: CanvasHandle.Kind) {
        sessions[Key(ownerID: ownerID, kind: kind)] = nil
    }
}

private struct CanvasHandleDragStateKey: CanvasEnvironmentKey {
    static var defaultValue: CanvasHandleDragState { CanvasHandleDragState() }
}

extension CanvasEnvironmentValues {
    var handleDragState: CanvasHandleDragState {
        get { self[CanvasHandleDragStateKey.self] }
        set { self[CanvasHandleDragStateKey.self] = newValue }
    }
}
