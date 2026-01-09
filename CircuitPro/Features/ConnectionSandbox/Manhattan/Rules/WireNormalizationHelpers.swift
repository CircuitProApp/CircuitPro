import CoreGraphics
import Foundation

func isPoint(
    _ p: CGPoint,
    onSegmentBetween a: CGPoint,
    p2 b: CGPoint,
    tol: CGFloat
) -> Bool {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) <= tol }
    let cross = (p.x - a.x) * dy - (p.y - a.y) * dx
    if abs(cross) > tol * sqrt(len2) { return false }
    let dot = (p.x - a.x) * dx + (p.y - a.y) * dy
    if dot < -tol || dot > len2 + tol { return false }
    return true
}

func selectSurvivor(
    from ids: [UUID],
    pointsByObject: [UUID: any ConnectionPoint]
) -> UUID {
    for id in ids {
        if let point = pointsByObject[id], !(point is WireVertex) {
            return id
        }
    }
    return ids.sorted { $0.uuidString < $1.uuidString }.first ?? ids.first ?? UUID()
}

func selectKeepID(from ids: [UUID], preferred: Set<UUID>) -> UUID {
    for id in ids where preferred.contains(id) {
        return id
    }
    return ids.first ?? UUID()
}
