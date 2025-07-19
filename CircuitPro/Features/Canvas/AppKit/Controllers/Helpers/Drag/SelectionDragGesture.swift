//
//  SelectionDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//  Refactored 17/07/25 – stripped connection-specific logic.
//

import AppKit

final class SelectionDragGesture: DragGesture {

    private struct DragModel {
        var originalVertexPositions: [UUID: CGPoint] = [:]
    }

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var originalPositions: [UUID: CGPoint] = [:] // For non-schematic elements
    private var dragModel = DragModel()
    private var didMove = false
    private let threshold: CGFloat = 4.0

    init(workbench: WorkbenchView) { self.workbench = workbench }

    // MARK: – Begin
    func begin(at p: CGPoint, event: NSEvent) -> Bool {
        let hitTarget = workbench.hitTestService.hitTest(
            at: p,
            elements: workbench.elements,
            schematicGraph: workbench.schematicGraph,
            magnification: workbench.magnification
        )

        guard let hitTarget = hitTarget,
              let selectableID = hitTarget.selectableID,
              workbench.selectedIDs.contains(selectableID) else {
            return false
        }

        origin = p
        originalPositions.removeAll()
        dragModel = DragModel()
        didMove = false

        // 1. Cache for standard elements
        for elt in workbench.elements where workbench.selectedIDs.contains(elt.id) {
            originalPositions[elt.id] = elt.transformable.position
        }

        // 2. Cache all vertex positions for the schematic drag model
        dragModel.originalVertexPositions = workbench.schematicGraph.vertices.mapValues { $0.point }
        
        return true
    }

    // MARK: – Drag
    func drag(to p: CGPoint) {
        guard let o = origin else { return }

        let rawDelta = CGPoint(x: p.x - o.x, y: p.y - o.y)

        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true
        
        let moveDelta = CGPoint(x: workbench.snapDelta(rawDelta.x),
                                y: workbench.snapDelta(rawDelta.y))

        // --- Part 1: Move standard canvas elements ---
        if !originalPositions.isEmpty {
            var updatedElements = workbench.elements
            for i in updatedElements.indices {
                guard let base = originalPositions[updatedElements[i].id] else { continue }
                updatedElements[i].moveTo(originalPosition: base, offset: moveDelta)
            }
            workbench.elements = updatedElements
            workbench.onUpdate?(updatedElements)
        }

        // --- Part 2: Move schematic components using BFS propagation ---
        let selectedEdges = workbench.schematicGraph.edges.values.filter {
            workbench.selectedIDs.contains($0.id)
        }
        guard !selectedEdges.isEmpty else {
            workbench.connectionsView?.needsDisplay = true
            return
        }

        var newPositions: [UUID: CGPoint] = [:]
        var queue: [UUID] = []
        
        // 1. Initial state: selected vertices move freely
        let primaryMovableVertices = Set(selectedEdges.flatMap { [$0.start, $0.end] })
        for id in primaryMovableVertices {
            if let origin = dragModel.originalVertexPositions[id] {
                newPositions[id] = CGPoint(x: origin.x + moveDelta.x, y: origin.y + moveDelta.y)
                queue.append(id)
            }
        }
        
        // 2. BFS to propagate constraints
        var head = 0
        while head < queue.count {
            let junctionID = queue[head]
            head += 1
            
            guard let junctionNewPos = newPositions[junctionID],
                  let adjacentEdgeIDs = workbench.schematicGraph.adjacency[junctionID] else { continue }

            for edgeID in adjacentEdgeIDs {
                guard let edge = workbench.schematicGraph.edges[edgeID], !workbench.selectedIDs.contains(edgeID) else { continue }
                
                let anchorID = edge.start == junctionID ? edge.end : edge.start
                if newPositions[anchorID] != nil { continue } // Already processed

                guard let anchorOrigPos = dragModel.originalVertexPositions[anchorID],
                      let junctionOrigPos = dragModel.originalVertexPositions[junctionID] else { continue }
                
                let wasHorizontal = abs(anchorOrigPos.y - junctionOrigPos.y) < 1e-6
                
                let newAnchorPos: CGPoint
                if wasHorizontal {
                    newAnchorPos = CGPoint(x: anchorOrigPos.x, y: junctionNewPos.y)
                } else { // Was vertical
                    newAnchorPos = CGPoint(x: junctionNewPos.x, y: anchorOrigPos.y)
                }
                
                newPositions[anchorID] = newAnchorPos
                queue.append(anchorID)
            }
        }

        // 3. Atomic update: Apply all calculated positions
        for (id, pos) in newPositions {
            workbench.schematicGraph.moveVertex(id: id, to: pos)
        }
        
        workbench.connectionsView?.needsDisplay = true
    }

    // MARK: – End
    func end() {
        if didMove && !dragModel.originalVertexPositions.isEmpty {
            workbench.schematicGraph.normalize(around: Set(dragModel.originalVertexPositions.keys))
        }
        
        origin = nil
        originalPositions.removeAll()
        dragModel = DragModel()
        didMove = false
        
        workbench.connectionsView?.needsDisplay = true
    }
}
