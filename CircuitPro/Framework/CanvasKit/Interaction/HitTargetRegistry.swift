import AppKit

struct CanvasDragDelta {
    let raw: CGPoint
    let processed: CGPoint
    let rawLocation: CGPoint
    let processedLocation: CGPoint
}

enum CanvasDragPhase {
    case began
    case changed(delta: CanvasDragDelta)
    case ended
}

struct CanvasHitTarget {
    let id: UUID
    let path: CGPath
    let priority: Int
    let depth: Int
    let onHover: ((Bool) -> Void)?
    let onTap: (() -> Void)?
    let onDrag: ((CanvasDragPhase, CanvasDragSession) -> Void)?
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
        var best: CanvasHitTarget?
        var bestPriority = Int.min
        var bestDepth = Int.min
        for target in targets.reversed() {
            if target.path.contains(point) {
                if target.priority > bestPriority {
                    best = target
                    bestPriority = target.priority
                    bestDepth = target.depth
                } else if target.priority == bestPriority, target.depth > bestDepth {
                    best = target
                    bestDepth = target.depth
                }
            }
        }
        return best
    }

    func hitTestAll(in rect: CGRect) -> [UUID] {
        var hits = Set<UUID>()
        for target in targets {
            if rect.intersects(target.path.boundingBoxOfPath) {
                hits.insert(target.id)
            }
        }
        return Array(hits)
    }
}
