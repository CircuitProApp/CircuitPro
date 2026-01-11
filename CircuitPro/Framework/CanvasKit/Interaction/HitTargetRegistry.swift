import AppKit

struct CanvasDragDelta {
    let raw: CGPoint
    let processed: CGPoint
}

enum CanvasDragPhase {
    case began
    case changed(delta: CanvasDragDelta)
    case ended
}

struct CanvasHitTarget {
    let id: UUID
    let path: CGPath
    let onHover: ((Bool) -> Void)?
    let onTap: (() -> Void)?
    let onDrag: ((CanvasDragPhase) -> Void)?
}

final class HitTargetRegistry {
    private(set) var targets: [CanvasHitTarget] = []

    func reset() {
        targets.removeAll(keepingCapacity: true)
    }

    func add(_ target: CanvasHitTarget) {
        targets.append(target)
    }

    func hitTest(_ point: CGPoint) -> CanvasHitTarget? {
        for target in targets.reversed() {
            if target.path.contains(point) {
                return target
            }
        }
        return nil
    }
}
