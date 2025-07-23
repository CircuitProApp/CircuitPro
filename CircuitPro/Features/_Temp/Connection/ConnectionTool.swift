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
                let newStartTarget = CanvasHitTarget.connection(part: .vertex(id: endVertexID, position: loc, type: .corner))
                state = .drawing(from: newStartTarget, at: loc, direction: newDirection)
            } else {
                state = .idle
            }
        }
        
        return .schematicModified
    }

    mutating func preview(mouse: CGPoint, context: CanvasToolContext) -> [DrawingParameters] {
        // 1. Ensure we are in the drawing state.
        guard case .drawing(_, let startPoint, let direction) = state else { return [] }

        // 2. Determine the corner point based on the current drawing direction.
        let corner: CGPoint
        switch direction {
        case .horizontal:
            corner = CGPoint(x: mouse.x, y: startPoint.y)
        case .vertical:
            corner = CGPoint(x: startPoint.x, y: mouse.y)
        }
        
        // 3. Create the two-segment path.
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: corner)
        path.addLine(to: mouse)

        // 4. Return the drawing parameters for the preview layer.
        return [DrawingParameters(
            path: path,
            lineWidth: 1.0,  // Model-space line width
            fillColor: nil,
            strokeColor: NSColor.systemBlue.cgColor,
            lineDashPattern: [4, 2] // Model-space dash pattern
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
    
    private func getOrCreateVertex(at point: CGPoint, from target: CanvasHitTarget?, in graph: SchematicGraph) -> UUID {
        if let target = target, case .canvasElement(let part) = target, case .pin(let pinID, let symbolID, _) = part {
            return graph.getOrCreatePinVertex(at: point, symbolID: symbolID!, pinID: pinID)
        } else {
            return graph.getOrCreateVertex(at: point)
        }
    }
    
    private func determineInitialDirection(from hitTarget: CanvasHitTarget?) -> DrawingDirection {
        guard let hitTarget = hitTarget else { return .horizontal }

        guard case .connection(let part) = hitTarget,
              case .edge(_, _, let orientation) = part else {
            return .horizontal
        }

        switch orientation {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}
