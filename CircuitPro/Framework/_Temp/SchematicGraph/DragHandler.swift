//
//  DragHandler.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/27/25.
//

import Foundation
import CoreGraphics

/// Encapsulates the drag state machine for wires/pins.
/// - Keeps a working GraphState that is updated during drag without running the ruleset.
/// - Uses ownership closures to read/update domain metadata (pins, detached pins).
/// - Produces a final epicenter for a localized resolve at endDrag.
final class DragHandler {
    private(set) var workingState: GraphState
    private let grid: GridPolicy
    private let lookup: (UUID) -> VertexOwnership?
    private let assign: (UUID, VertexOwnership) -> Void

    // Frozen at begin()
    private var originalVertexPositions: [UUID: CGPoint] = [:]
    private var selectedEdges: [GraphEdge] = []
    private var selectedEdgeIDs: Set<UUID> = []
    private var verticesToMove: Set<UUID> = []

    // Accumulated during update()
    private var newVertices: Set<UUID> = []

    init(state: GraphState,
         grid: GridPolicy,
         lookup: @escaping (UUID) -> VertexOwnership?,
         assign: @escaping (UUID, VertexOwnership) -> Void) {
        self.workingState = state
        self.grid = grid
        self.lookup = lookup
        self.assign = assign
    }

    /// Computes the drag seed sets and snapshots original positions.
    /// Mirrors the logic you had in WireGraph.beginDrag.
    @discardableResult
    func begin(selectedIDs: Set<UUID>) -> Bool {
        let s = workingState
        originalVertexPositions = s.vertices.mapValues { $0.point }

        // 1) Pins of selected symbols
        let symbolPinVertexIDs = s.vertices.keys.filter { vid in
            if case .pin(let ownerID, _) = lookup(vid) { return selectedIDs.contains(ownerID) }
            return false
        }

        // 2) Selected edges
        selectedEdges = s.edges.values.filter { selectedIDs.contains($0.id) }
        selectedEdgeIDs = Set(selectedEdges.map { $0.id })

        // 3) Movable vertices from those edges, excluding pins
        let movableEdgeVertexIDs = selectedEdges
            .flatMap { [$0.start, $0.end] }
            .filter { vid in
                if case .pin = lookup(vid) { return false }
                return true
            }

        verticesToMove = Set(symbolPinVertexIDs).union(movableEdgeVertexIDs)
        return !verticesToMove.isEmpty
    }

    /// Applies the drag delta to workingState without running the ruleset.
    /// Returns the updated working GraphState so the caller can replace engine state.
    func update(by delta: CGPoint) -> GraphState {
        var s = workingState
        let tol = grid.epsilon

        // 1) Pre-process: detaching selected pins that are pulled off-axis
        for vertexID in verticesToMove {
            guard case .pin = lookup(vertexID) else { continue }

            let isOffAxis = (s.adjacency[vertexID] ?? []).contains { edgeID in
                guard selectedEdgeIDs.contains(edgeID) else { return false }
                guard let e = s.edges[edgeID] else { return false }
                let otherEndID = (e.start == vertexID) ? e.end : e.start
                if verticesToMove.contains(otherEndID) { return false }
                guard let orig = originalVertexPositions[vertexID],
                      let otherOrig = originalVertexPositions[otherEndID] else { return false }
                let wasHorizontal = abs(orig.y - otherOrig.y) < tol
                return (wasHorizontal && abs(delta.y) > tol) || (!wasHorizontal && abs(delta.x) > tol)
            }

            if isOffAxis {
                let pinOwnership = lookup(vertexID) ?? .free
                let pinPoint = s.vertices[vertexID]?.point ?? .zero
                assign(vertexID, .detachedPin) // domain metadata indicates temporary detach
                let newStatic = s.addVertex(at: pinPoint, clusterID: s.vertices[vertexID]?.clusterID)
                newVertices.insert(newStatic.id)
                assign(newStatic.id, pinOwnership) // transfer "real pin" marking to static vertex
                _ = s.addEdge(from: vertexID, to: newStatic.id)
            }
        }

        // 2) Initial displaced positions for the moving set
        var newPositions: [UUID: CGPoint] = [:]
        for id in verticesToMove {
            if let origin = originalVertexPositions[id] {
                newPositions[id] = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
            }
        }

        // 3) L-bend for vertices that are now detached pins
        for vertexID in verticesToMove where lookup(vertexID) == .detachedPin {
            guard
                let staticPinNeighbor = findNeighbor(of: vertexID, in: s, where: { nID, _ in
                    if case .pin = self.lookup(nID) { return newPositions[nID] == nil } else { return false }
                }),
                let movingNeighbor = findNeighbor(of: vertexID, in: s, where: { nID, e in
                    return newPositions[nID] != nil && self.selectedEdgeIDs.contains(e.id)
                }),
                let origV = originalVertexPositions[vertexID],
                let origM = originalVertexPositions[movingNeighbor.id],
                let newM = newPositions[movingNeighbor.id]
            else { continue }

            let wasHorizontal = abs(origV.y - origM.y) < tol
            newPositions[vertexID] = wasHorizontal
                ? CGPoint(x: staticPinNeighbor.point.x, y: newM.y)
                : CGPoint(x: newM.x, y: staticPinNeighbor.point.y)
        }

        // 4) Propagate axis constraints via BFS from the moving set
        var queue = Array(verticesToMove)
        var queued = verticesToMove
        var head = 0

        while head < queue.count {
            let junctionID = queue[head]; head += 1
            guard let junctionNewPos = newPositions[junctionID],
                  let junctionOrigPos = originalVertexPositions[junctionID] else { continue }

            for edgeID in s.adjacency[junctionID] ?? [] {
                guard let e = s.edges[edgeID] else { continue }
                let anchorID = (e.start == junctionID) ? e.end : e.start
                if verticesToMove.contains(anchorID) { continue }

                guard let anchorOrigPos = originalVertexPositions[anchorID] else { continue }
                var updatedAnchorPos = newPositions[anchorID] ?? anchorOrigPos
                let wasHorizontal = abs(anchorOrigPos.y - junctionOrigPos.y) < tol

                if case .pin(let owner, let pin) = lookup(anchorID) {
                    let isOffAxisPull = (wasHorizontal && abs(junctionNewPos.y - anchorOrigPos.y) > tol)
                        || (!wasHorizontal && abs(junctionNewPos.x - anchorOrigPos.x) > tol)
                    if isOffAxisPull {
                        updatedAnchorPos = wasHorizontal
                            ? CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y)
                            : CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)

                        // Temporarily detach the anchor pin
                        assign(anchorID, .detachedPin)
                        let newStaticPin = s.addVertex(at: anchorOrigPos, clusterID: s.vertices[anchorID]?.clusterID)
                        newVertices.insert(newStaticPin.id)
                        assign(newStaticPin.id, .pin(ownerID: owner, pinID: pin))
                        _ = s.addEdge(from: anchorID, to: newStaticPin.id)
                    } else {
                        continue
                    }
                } else {
                    if wasHorizontal { updatedAnchorPos.y = junctionNewPos.y }
                    else { updatedAnchorPos.x = junctionNewPos.x }
                }

                if newPositions[anchorID] != updatedAnchorPos {
                    newPositions[anchorID] = updatedAnchorPos
                    if !queued.contains(anchorID) {
                        queue.append(anchorID)
                        queued.insert(anchorID)
                    }
                }
            }
        }

        // 5) Apply positions atomically (no normalization)
        for (id, pos) in newPositions {
            if s.vertices[id]?.point != pos {
                s.vertices[id]?.point = pos
            }
        }

        workingState = s
        return s
    }

    /// Finalizes the drag:
    /// - Converts temporary detached pins back to .free
    /// - Returns the epicenter for a localized resolve and the final working state
    func end() -> (finalState: GraphState, epicenter: Set<UUID>) {
        // Convert temporary detached pins back to free (domain metadata only)
        for (vid, _) in workingState.vertices {
            if lookup(vid) == .detachedPin {
                assign(vid, .free)
            }
        }

        // Epicenter includes all originally touched vertices and any created vertices during drag
        let epicenter = Set(originalVertexPositions.keys).union(newVertices)
        return (workingState, epicenter)
    }

    // MARK: - Helpers

    private func findNeighbor(of vertexID: UUID,
                              in state: GraphState,
                              where predicate: (UUID, GraphEdge) -> Bool) -> GraphVertex? {
        guard let edgeIDs = state.adjacency[vertexID] else { return nil }
        for eid in edgeIDs {
            guard let e = state.edges[eid] else { continue }
            let nid = (e.start == vertexID) ? e.end : e.start
            if predicate(nid, e) { return state.vertices[nid] }
        }
        return nil
    }
}

extension VertexOwnership: Equatable {
    static func ==(lhs: VertexOwnership, rhs: VertexOwnership) -> Bool {
        switch (lhs, rhs) {
        case (.free, .free): return true
        case (.detachedPin, .detachedPin): return true
        case let (.pin(lo, lp), .pin(ro, rp)): return lo == ro && lp == rp
        default: return false
        }
    }
}
