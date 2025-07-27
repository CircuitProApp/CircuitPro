//
//  ConnectionTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/18/25.
//

import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {

    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label = "Connection"

    // MARK: - Types
    private enum DrawingDirection: Equatable, Hashable {
        case horizontal
        case vertical

        func toggled() -> DrawingDirection {
            self == .horizontal ? .vertical : .horizontal
        }
    }

    // MARK: - State
    private enum State: Equatable, Hashable {
        case idle
        case drawing(from: CanvasHitTarget?, at: CGPoint, direction: DrawingDirection)
    }

    private var state: State = .idle

    // MARK: – CanvasTool Conformance
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        guard let graph = context.schematicGraph else {
            assertionFailure("ConnectionTool requires a schematic graph in the context.")
            return .noResult
        }

        if context.clickCount > 1 {
            state = .idle
            return .schematicModified
        }

        switch state {
        case .idle:
            let initialDirection = determineInitialDirection(from: context.hitTarget)
            state = .drawing(from: context.hitTarget, at: loc, direction: initialDirection)
            return .noResult

        case .drawing(let startTarget, let startPoint, let direction):
            let endTarget = context.hitTarget

            if startTarget == nil && endTarget == nil && startPoint == loc { return .noResult }

            let startVertexID = getOrCreateVertex(at: startPoint, from: startTarget, in: graph)
            let endVertexID = getOrCreateVertex(at: loc, from: endTarget, in: graph)

            if startVertexID == endVertexID {
                state = .idle
                return .schematicModified
            }
            
            let isStraightLine = (startPoint.x == loc.x || startPoint.y == loc.y)
            let strategy: SchematicGraph.ConnectionStrategy = (direction == .horizontal) ? .horizontalThenVertical : .verticalThenHorizontal
            graph.connect(from: startVertexID, to: endVertexID, preferring: strategy)

            if endTarget == nil {
                let newDirection = isStraightLine ? direction.toggled() : direction
                // **UPDATED**: Create the new CanvasHitTarget struct.
                let newStartTarget = CanvasHitTarget(
                    partID: endVertexID,
                    ownerPath: [], // A vertex has no selectable owner.
                    kind: .vertex(type: .corner),
                    position: loc
                )
                state = .drawing(from: newStartTarget, at: loc, direction: newDirection)
            } else {
                state = .idle
            }
        }
        
        return .schematicModified
    }

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> [DrawingParameters] {
        // This preview logic remains unchanged as it only depends on state, not the structure of CanvasHitTarget.
        guard case .drawing(_, let startPoint, let direction) = state else { return [] }

        let corner: CGPoint
        switch direction {
        case .horizontal:
            corner = CGPoint(x: mouse.x, y: startPoint.y)
        case .vertical:
            corner = CGPoint(x: startPoint.x, y: mouse.y)
        }
        
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: corner)
        path.addLine(to: mouse)

        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.cgColor,
            lineDashPattern: [4, 2]
        )]
    }

    // MARK: - Tool State Management
    mutating func handleEscape() {
        if case .drawing = state { state = .idle }
    }

    mutating func handleReturn() -> CanvasToolResult {
        if case .drawing = state {
            state = .idle
            return .schematicModified
        }
        return .noResult
    }

    mutating func handleBackspace() {
        // TODO: Implement backspace
    }
    
    // MARK: - Private Helpers
    
    // **UPDATED**: This helper now deconstructs the new CanvasHitTarget struct.
    private func getOrCreateVertex(at point: CGPoint, from target: CanvasHitTarget?, in graph: SchematicGraph) -> UUID {
        guard let target = target else {
            return graph.getOrCreateVertex(at: point)
        }

        // Check if the hit target was a pin.
        if case .pin = target.kind {
            // A pin must be owned by a symbol to be connected. The owner is the last ID in the path.
            if let symbolID = target.ownerPath.last {
                // The pin's ID is the partID from the hit record.
                return graph.getOrCreatePinVertex(at: point, symbolID: symbolID, pinID: target.partID)
            }
        }
        
        // For any other kind of hit (or a pin without an owner), create a standard vertex.
        return graph.getOrCreateVertex(at: point)
    }
    
    // **UPDATED**: This helper now checks the `.kind` property of the new struct.
    private func determineInitialDirection(from hitTarget: CanvasHitTarget?) -> DrawingDirection {
        guard let hitTarget = hitTarget else { return .horizontal }

        // Check if the hit target was an edge and extract its orientation.
        guard case .edge(let orientation) = hitTarget.kind else {
            return .horizontal
        }

        // If we hit an edge, the next drawing direction should be perpendicular to it.
        switch orientation {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}
