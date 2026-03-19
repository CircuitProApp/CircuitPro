import CoreGraphics
import Foundation

/// Computes new vertex positions when dragging a trace segment, preserving
/// the 45°/orthogonal character of all segments at shared junctions.
///
/// Resolution strategy depends on the **incident segment's orientation**:
///
/// **Orthogonal incident (vertical/horizontal):**
/// For dragged diagonals, try both diagonal families through the dragged far end,
/// apply the anchor reflection rule, then keep the junction closest to its original
/// position. This preserves bounce behavior while still allowing the dragged segment
/// to flip between ascending and descending when that is the nearest valid result.
///
///   Drag E2 (ascending diagonal) downward by 50 → junction slides from (0,100) to (0,50)
///   Drag E2 downward by 100 → junction reaches anchor (0,0), E1 dissolves
///   Drag E2 downward by 150 → junction crosses anchor, reflected to (0,50) — E1 reappears
///   Drag E2 left by 200 → junction stays at (0,100), E2 flips descending
///
/// **Diagonal incident (ascending/descending):**
/// Try all combinations of dragged-line options × incident-orientation options,
/// pick the candidate closest to the original junction. This handles both natural
/// sliding and axis-crossing / mirroring without special cases.
///
///   Drag E2 (vertical) left by 50, E1 (ascending) incident:
///     candidates (−50,−50) dist≈71, (−50,250) dist≈260 → pick (−50,−50)
///   Drag E1 (vertical) right by 200, E2 (ascending) incident:
///     candidates (200,300) dist≈283, (200,100) dist=200 → pick (200,100)
///   Drag E1 (ascending diagonal) left by 200, E2 (vertical) incident:
///     primary ascending→(0,200) dist=200, primary descending→(0,0) dist=0 → pick (0,0)
enum TraceSegmentDragSolver {

    static func solve(
        draggedID: UUID,
        startID: UUID,
        endID: UUID,
        delta: CGVector,
        originalPositions: [UUID: CGPoint],
        layerSegments: [TraceSegment],
        orientations: [UUID: ConnectionSegmentOrientation],
        fixedPointIDs: Set<UUID>
    ) -> [UUID: CGPoint] {
        guard let startPos = originalPositions[startID],
            let endPos = originalPositions[endID]
        else { return [:] }

        let newStart = CGPoint(x: startPos.x + delta.dx, y: startPos.y + delta.dy)
        let newEnd = CGPoint(x: endPos.x + delta.dx, y: endPos.y + delta.dy)

        let draggedOrientation = orientations[draggedID]

        let startIncidents = incidents(at: startID, excluding: draggedID, in: layerSegments)
        let endIncidents = incidents(at: endID, excluding: draggedID, in: layerSegments)

        var result: [UUID: CGPoint] = [:]

        result[startID] = resolveEndpoint(
            id: startID,
            isFixed: fixedPointIDs.contains(startID),
            translatedPos: newStart,
            draggedOtherEnd: newEnd,
            draggedLineP1: newStart,
            draggedLineP2: newEnd,
            draggedOrientation: draggedOrientation,
            junctionIncidents: startIncidents,
            originalPositions: originalPositions,
            orientations: orientations,
            fixedPointIDs: fixedPointIDs
        )

        result[endID] = resolveEndpoint(
            id: endID,
            isFixed: fixedPointIDs.contains(endID),
            translatedPos: newEnd,
            draggedOtherEnd: newStart,
            draggedLineP1: newStart,
            draggedLineP2: newEnd,
            draggedOrientation: draggedOrientation,
            junctionIncidents: endIncidents,
            originalPositions: originalPositions,
            orientations: orientations,
            fixedPointIDs: fixedPointIDs
        )

        if result[startID] == originalPositions[startID] { result.removeValue(forKey: startID) }
        if result[endID] == originalPositions[endID] { result.removeValue(forKey: endID) }

        return result
    }

    // MARK: - Private

    private static func resolveEndpoint(
        id: UUID,
        isFixed: Bool,
        translatedPos: CGPoint,
        draggedOtherEnd: CGPoint,
        draggedLineP1: CGPoint,
        draggedLineP2: CGPoint,
        draggedOrientation: ConnectionSegmentOrientation?,
        junctionIncidents: [TraceSegment],
        originalPositions: [UUID: CGPoint],
        orientations: [UUID: ConnectionSegmentOrientation],
        fixedPointIDs: Set<UUID>
    ) -> CGPoint {
        if isFixed { return originalPositions[id] ?? translatedPos }
        guard !junctionIncidents.isEmpty else { return translatedPos }

        let originalJunction = originalPositions[id] ?? translatedPos

        let sorted = junctionIncidents.sorted { a, b in
            fixedFarEndpoint(of: a, junction: id, fixedPointIDs: fixedPointIDs)
                && !fixedFarEndpoint(of: b, junction: id, fixedPointIDs: fixedPointIDs)
        }

        for incident in sorted {
            let farEndID = incident.startID == id ? incident.endID : incident.startID
            guard let anchor = originalPositions[farEndID],
                let incOrientation = orientations[incident.id]
            else { continue }

            switch incOrientation {
            case .horizontal, .vertical:
                // Orthogonal incident: evaluate all valid dragged-line options, bounce any
                // candidate that crosses past the anchor, then keep the closest junction.
                guard
                    let best = closestOrthogonalCandidate(
                        draggedLineP1: draggedLineP1,
                        draggedLineP2: draggedLineP2,
                        draggedOtherEnd: draggedOtherEnd,
                        draggedOrientation: draggedOrientation,
                        originalJunction: originalJunction,
                        anchor: anchor,
                        incOrientation: incOrientation
                    )
                else { continue }
                return best

            case .diagonalAscending, .diagonalDescending:
                // Diagonal incident: generate all (dragged-line × incident-orientation)
                // combinations and pick the candidate closest to the original junction.
                if let best = closestCandidate(
                    draggedLineP1: draggedLineP1,
                    draggedLineP2: draggedLineP2,
                    draggedOtherEnd: draggedOtherEnd,
                    draggedOrientation: draggedOrientation,
                    anchor: anchor,
                    incOrientation: incOrientation,
                    originalJunction: originalJunction
                ) {
                    return best
                }

            default:
                break
            }
        }

        return translatedPos
    }

    // MARK: Orthogonal-incident helpers

    /// For orthogonal incidents, evaluates the valid dragged-line options and returns
    /// the bounced candidate nearest the original junction.
    private static func closestOrthogonalCandidate(
        draggedLineP1: CGPoint,
        draggedLineP2: CGPoint,
        draggedOtherEnd farEnd: CGPoint,
        draggedOrientation: ConnectionSegmentOrientation?,
        originalJunction: CGPoint,
        anchor: CGPoint,
        incOrientation: ConnectionSegmentOrientation
    ) -> CGPoint? {
        let draggedLines = draggedLineOptions(
            p1: draggedLineP1,
            p2: draggedLineP2,
            farEnd: farEnd,
            orientation: draggedOrientation
        )

        var best: CGPoint?
        var bestDist = CGFloat.infinity

        for (lp1, lp2) in draggedLines {
            guard
                let raw = intersect(
                    lineP1: lp1,
                    lineP2: lp2,
                    anchor: anchor,
                    orientation: incOrientation
                )
            else { continue }

            let candidate = reflectedIfPast(
                raw,
                originalJunction: originalJunction,
                anchor: anchor,
                orientation: incOrientation
            )
            let distance = squaredDistance(candidate, originalJunction)
            if distance < bestDist {
                best = candidate
                bestDist = distance
            }
        }

        return best
    }

    /// Returns `junction` unchanged if it is on the same side of `anchor` as
    /// `originalJunction` along the incident's axis. If it has crossed to the opposite
    /// side (past the anchor), reflects it back so the junction "bounces".
    ///
    ///   anchor=(0,0), originalJunction=(0,100), junction=(0,−50) → reflected=(0,50)
    private static func reflectedIfPast(
        _ junction: CGPoint,
        originalJunction: CGPoint,
        anchor: CGPoint,
        orientation: ConnectionSegmentOrientation
    ) -> CGPoint {
        guard let d = orientation.direction else { return junction }
        let s0 = (originalJunction.x - anchor.x) * d.dx + (originalJunction.y - anchor.y) * d.dy
        let s1 = (junction.x - anchor.x) * d.dx + (junction.y - anchor.y) * d.dy
        guard s0 * s1 < 0 else { return junction }
        // Reflect: move from the wrong side back by the same magnitude.
        return CGPoint(x: anchor.x - s1 * d.dx, y: anchor.y - s1 * d.dy)
    }

    // MARK: Diagonal-incident helpers

    /// Tries all (dragged-line option × incident-orientation) combinations and returns
    /// the candidate closest to `originalJunction`.
    private static func closestCandidate(
        draggedLineP1: CGPoint,
        draggedLineP2: CGPoint,
        draggedOtherEnd: CGPoint,
        draggedOrientation: ConnectionSegmentOrientation?,
        anchor: CGPoint,
        incOrientation: ConnectionSegmentOrientation,
        originalJunction: CGPoint
    ) -> CGPoint? {
        let draggedLines = draggedLineOptions(
            p1: draggedLineP1, p2: draggedLineP2,
            farEnd: draggedOtherEnd, orientation: draggedOrientation
        )
        let incOrientations = incidentOrientationOptions(incOrientation)

        var best: CGPoint?
        var bestDist = CGFloat.infinity

        for (lp1, lp2) in draggedLines {
            for inc in incOrientations {
                guard
                    let candidate = intersect(
                        lineP1: lp1, lineP2: lp2,
                        anchor: anchor, orientation: inc)
                else { continue }
                let d = squaredDistance(candidate, originalJunction)
                if d < bestDist {
                    bestDist = d
                    best = candidate
                }
            }
        }
        return best
    }

    private static func draggedLineOptions(
        p1: CGPoint, p2: CGPoint,
        farEnd: CGPoint,
        orientation: ConnectionSegmentOrientation?
    ) -> [(CGPoint, CGPoint)] {
        switch orientation {
        case .diagonalAscending, .diagonalDescending:
            return [
                (farEnd, CGPoint(x: farEnd.x + 1, y: farEnd.y + 1)),
                (farEnd, CGPoint(x: farEnd.x + 1, y: farEnd.y - 1)),
            ]
        default:
            return [(p1, p2)]
        }
    }

    private static func incidentOrientationOptions(
        _ orientation: ConnectionSegmentOrientation
    ) -> [ConnectionSegmentOrientation] {
        switch orientation {
        case .diagonalAscending, .diagonalDescending:
            return [.diagonalAscending, .diagonalDescending]
        default:
            return [orientation]
        }
    }

    // MARK: Shared helpers

    private static func fixedFarEndpoint(
        of segment: TraceSegment,
        junction: UUID,
        fixedPointIDs: Set<UUID>
    ) -> Bool {
        let farID = segment.startID == junction ? segment.endID : segment.startID
        return fixedPointIDs.contains(farID)
    }

    private static func incidents(
        at id: UUID,
        excluding excludedID: UUID,
        in segments: [TraceSegment]
    ) -> [TraceSegment] {
        segments.filter { $0.id != excludedID && ($0.startID == id || $0.endID == id) }
    }

    private static func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    /// Intersects line A (through `lineP1`/`lineP2`) with line B (through `anchor`
    /// in the direction of `orientation`). Returns nil for parallel lines or
    /// arbitrary orientation.
    static func intersect(
        lineP1 p1: CGPoint,
        lineP2 p2: CGPoint,
        anchor: CGPoint,
        orientation: ConnectionSegmentOrientation
    ) -> CGPoint? {
        guard let d2 = orientation.direction else { return nil }
        let d1 = CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
        let det = d1.dx * (-d2.dy) + d2.dx * d1.dy
        guard abs(det) > 1e-9 else { return nil }
        let rx = anchor.x - p1.x
        let ry = anchor.y - p1.y
        let t = (rx * (-d2.dy) + d2.dx * ry) / det
        return CGPoint(x: p1.x + t * d1.dx, y: p1.y + t * d1.dy)
    }
}
