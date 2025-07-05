//
//  ConnectionElement.swift
//  CircuitPro
//
//  Updated 02 Jul 2025
//

import SwiftUI
import AppKit

struct ConnectionElement: Identifiable, Drawable, Hittable, Transformable {

    let id: UUID
    let net: Net

    // MARK: - Properties From Protocols
    var position: CGPoint = .zero
    var rotation: CGFloat = .zero

    // This computed property remains unchanged, providing primitives for drawing and hit-testing.
    var primitives: [AnyPrimitive] {
        net.edges.map { edge in
            let nodeA = net.nodeByID[edge.a]!
            let nodeB = net.nodeByID[edge.b]!
            return .line(
                LinePrimitive(
                    id: edge.id, // The edge's ID is used for segment selection.
                    start: nodeA.point,
                    end: nodeB.point,
                    rotation: 0,
                    strokeWidth: 1,
                    color: SDColor(color: .blue)
                )
            )
        }
    }

    // MARK: - Drawing Conformance (Drawable)
    
    // This is the NEW custom implementation of the protocol method.
    // It overrides the default implementation to provide specialized selection drawing.
    func draw(in ctx: CGContext, with selection: Set<UUID>) {
        
        // --- Step 1: Draw Selection Halos ---

        // Case A: The entire net is selected as one unit.
        // We use `selectionPath()` to draw a halo around the whole thing.
        if selection.contains(self.id) {
            if let outline = self.selectionPath() {
                ctx.saveGState()
                // These values can be sourced from your protocol extension constants.
                ctx.setStrokeColor(NSColor(.blue.opacity(0.3)).cgColor)
                ctx.setLineWidth(4)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.addPath(outline)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
        // Case B: Only individual segments (edges) are selected.
        else {
            let selectedPath = CGMutablePath()
            var hasSelection = false
            for prim in self.primitives where selection.contains(prim.id) {
                selectedPath.addPath(prim.makePath())
                hasSelection = true
            }

            // Only draw the halo if we found selected segments.
            if hasSelection {
                 ctx.saveGState()
                 ctx.setStrokeColor(NSColor(.blue.opacity(0.3)).cgColor)
                 ctx.setLineWidth(4)
                 ctx.setLineCap(.round)
                 ctx.addPath(selectedPath)
                 ctx.strokePath()
                 ctx.restoreGState()
            }
        }
        
        // --- Step 2: Draw the Element Body ---
        // This is always called last, drawing the wires and dots on top of any halos.
        self.drawBody(in: ctx)
    }

    // This required protocol method remains unchanged. It helps draw the unselected body.
    func drawBody(in ctx: CGContext) {
        // 1. Draw all the wire segments for the net.
        primitives.forEach { $0.drawBody(in: ctx) }

        // 2. Draw junction dots over the wires.
        let radius: CGFloat = 3.0
        ctx.saveGState()
        ctx.setFillColor(NSColor(.blue).cgColor)
        for node in net.nodeByID.values where node.kind == .junction {
            let rect = CGRect(x: node.point.x - radius, y: node.point.y - radius,
                              width: radius * 2, height: radius * 2)
            ctx.fillEllipse(in: rect)
        }
        ctx.restoreGState()
    }

    func selectionPath() -> CGPath? {
        let path = CGMutablePath()
        primitives.forEach { path.addPath($0.makePath()) }
        return path
    }

    // MARK: - Hit Testing Conformance (Hittable)
    // These methods remain unchanged.
    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        primitives.contains { $0.hitTest(point, tolerance: tolerance) }
    }

    func hitSegmentID(at p: CGPoint, tolerance: CGFloat = 5) -> UUID? {
        primitives.first { $0.hitTest(p, tolerance: tolerance) }?.id
    }
}

// MARK: - Protocol Conformances
extension ConnectionElement: Hashable {
    func hash(into h: inout Hasher) { h.combine(id) }
}

// We can also add a helper to CGFloat for line calculations.
extension CGFloat {
    func isBetween(_ a: CGFloat, _ b: CGFloat) -> Bool {
        (Swift.min(a, b)...Swift.max(a, b)).contains(self)
    }
}
