//
//  ConnectionElement.swift
//  CircuitPro
//

import SwiftUI
import AppKit

// Note: Transformable conformance has been removed. See comments below.
struct ConnectionElement: Identifiable, Drawable, Hittable {

    // MARK: – Identity
    let id: UUID
    private(set) var revision: Int = 0

    // MARK: - Data Model
    /// The underlying graph representing the connection net.
    /// Using a class for ConnectionGraph allows for reference semantics,
    /// where multiple elements could potentially share and manipulate the same net.
    let graph: ConnectionGraph

    // Bump this whenever the underlying graph changes so SwiftUI detects updates
    mutating func markChanged() { revision &+= 1 }

    // MARK: – Init
    init(
        id: UUID = .init(),
        graph: ConnectionGraph
    ) {
        self.id = id
        self.graph = graph
        self.revision = 0
    }

    // MARK: – Derived geometry
    
    /// The segments of the connection, derived from the graph model.
    /// These segments are in the world coordinate space.
    var segments: [ConnectionSegment] {
        graph.edges.values.compactMap { edge in
            guard let startVertex = graph.vertices[edge.start],
                  let endVertex = graph.vertices[edge.end] else {
                return nil
            }
            return ConnectionSegment(id: edge.id, start: startVertex.point, end: endVertex.point)
        }
    }
    
    var primitives: [AnyPrimitive] {
        segments.map { seg in
            .line(
                LinePrimitive(
                    id:          seg.id,
                    start:       seg.start,
                    end:         seg.end,
                    rotation:    0,
                    strokeWidth: 1,
                    color:       SDColor(color: .blue)
                )
            )
        }
    }

    /// With the removal of Transformable, the concept of a local-to-world transform
    /// for the entire element is no longer applicable. All geometry in the
    /// ConnectionGraph is stored in world coordinates. This simplifies merging
    /// and manipulation of complex nets, as we no longer need to bake-in transforms.
    /// Individual vertices or segments can still be transformed by directly
    /// manipulating the data in the ConnectionGraph.

    // MARK: – Drawable
    func draw(in ctx: CGContext, with selection: Set<UUID>, allPinPositions: [CGPoint]) {
        // Draw the main body of the connection, respecting selection for draw order.
        // Selected segments will be drawn on top of junctions.
        drawBody(in: ctx, with: selection, allPinPositions: allPinPositions)

        // Draw the selection highlights on top of everything.
        drawSelection(in: ctx, selection: selection, allPinPositions: allPinPositions)
    }

    private func drawSelection(in ctx: CGContext, selection: Set<UUID>, allPinPositions: [CGPoint]) {
        // 1. Whole-connection selected?
        if selection.contains(id), let outline = selectionPath() {
            let combinedPath = CGMutablePath()
            combinedPath.addPath(outline)

            let endpointDiameter: CGFloat = 8
            for (vertexID, edgeIDs) in graph.adjacency {
                guard let vertex = graph.vertices[vertexID] else { continue }
                let connectionCount = edgeIDs.count

                if connectionCount == 1 { // Potential free-floating endpoint
                    // Check if this vertex is on a pin
                    let isAttached = allPinPositions.contains { pinPos in
                        hypot(vertex.point.x - pinPos.x, vertex.point.y - pinPos.y) < 0.01
                    }

                    if !isAttached {
                        let r = CGRect(
                            x: vertex.point.x - endpointDiameter / 2,
                            y: vertex.point.y - endpointDiameter / 2,
                            width: endpointDiameter,
                            height: endpointDiameter
                        )
                        combinedPath.addEllipse(in: r)
                    }
                }
            }

            ctx.saveGState()
            ctx.setBlendMode(.screen)
            ctx.setStrokeColor(NSColor(.blue.opacity(0.3)).cgColor)
            ctx.setLineWidth(4)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(combinedPath)
            ctx.strokePath()
            ctx.restoreGState()
            return
        }

        // 2. Individual segments and their free ends selected?
        let selectedPath = CGMutablePath()
        var hasSelection = false
        var freeEndVertexIDs = Set<UUID>()

        // Collect selected segments and their free ends
        for primitive in primitives where selection.contains(primitive.id) {
            selectedPath.addPath(primitive.makePath())
            hasSelection = true

            guard let edge = graph.edges[primitive.id] else { continue }
            for vertexID in [edge.start, edge.end] {
                if let adjacency = graph.adjacency[vertexID], adjacency.count == 1 {
                    freeEndVertexIDs.insert(vertexID)
                }
            }
        }

        // If segments are selected, add their free-end vertices to the path
        if hasSelection {
            let endpointDiameter: CGFloat = 8
            for vertexID in freeEndVertexIDs {
                guard let vertex = graph.vertices[vertexID] else { continue }
                let r = CGRect(
                    x: vertex.point.x - endpointDiameter / 2,
                    y: vertex.point.y - endpointDiameter / 2,
                    width: endpointDiameter,
                    height: endpointDiameter
                )
                selectedPath.addEllipse(in: r)
            }

            // Stroke the combined path for a unified highlight
            ctx.saveGState()
            ctx.setBlendMode(.screen)
            ctx.setStrokeColor(NSColor(.blue.opacity(0.3)).cgColor)
            ctx.setLineWidth(4)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(selectedPath)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    func drawBody(in ctx: CGContext) {
        drawBody(in: ctx, with: [], allPinPositions: [])
    }

    internal func drawBody(in ctx: CGContext, with selection: Set<UUID> = [], allPinPositions: [CGPoint]) {
        // 1. Draw unselected wires
        primitives
            .filter { !selection.contains($0.id) }
            .forEach { $0.drawBody(in: ctx) }

        // 2. Draw junction dots and endpoints
        ctx.saveGState()
        ctx.setFillColor(NSColor(.blue).cgColor)
        let junctionDiameter: CGFloat = 6
        let endpointDiameter: CGFloat = 8

        for (vertexID, edgeIDs) in graph.adjacency {
            guard let vertex = graph.vertices[vertexID] else { continue }
            let connectionCount = edgeIDs.count

            if connectionCount > 2 { // Junction
                let r = CGRect(
                    x: vertex.point.x - junctionDiameter / 2,
                    y: vertex.point.y - junctionDiameter / 2,
                    width: junctionDiameter,
                    height: junctionDiameter
                )
                ctx.fillEllipse(in: r)
            } else if connectionCount == 1 { // Potential free-floating endpoint
                // Check if this vertex is on a pin
                let isAttached = allPinPositions.contains { pinPos in
                    hypot(vertex.point.x - pinPos.x, vertex.point.y - pinPos.y) < 0.01
                }

                if !isAttached {
                    let r = CGRect(
                        x: vertex.point.x - endpointDiameter / 2,
                        y: vertex.point.y - endpointDiameter / 2,
                        width: endpointDiameter,
                        height: endpointDiameter
                    )
                    
                    ctx.setLineWidth(1.0) // Optional: adjust stroke width
                    ctx.setStrokeColor(NSColor(.blue).cgColor) // Optional: set stroke color
                    ctx.strokeEllipse(in: r)
                }
            }
        }
        ctx.restoreGState()
        
        // 3. Draw selected wires on top of junctions using a blend mode
        // to make them visually distinct.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        primitives
            .filter { selection.contains($0.id) }
            .forEach { $0.drawBody(in: ctx) }
        ctx.restoreGState()
    }

    // MARK: – Hittable
    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        primitives.contains { $0.hitTest(point, tolerance: tolerance) }
    }

    // MARK: – Selection helpers
    func selectionPath() -> CGPath? {
        let path = CGMutablePath()
        primitives.forEach { path.addPath($0.makePath()) }
        return path.copy(
            strokingWithWidth: 1,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 0,
            transform: .identity
        )
    }
}

// MARK: – Hashable & Equatable
extension ConnectionElement: Hashable, Equatable {
    static func == (lhs: ConnectionElement, rhs: ConnectionElement) -> Bool {
        lhs.id == rhs.id && lhs.revision == rhs.revision
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(revision)
    }
}
