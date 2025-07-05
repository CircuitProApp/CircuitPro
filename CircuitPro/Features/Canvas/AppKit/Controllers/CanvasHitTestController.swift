//
//  CanvasHitTestController.swift
//  Circuit Pro_Tests
//
//  Created by Giorgi Tchelidze on 5/16/25.
//
import AppKit

// MARK: - CanvasHitTestController.swift
final class CanvasHitTestController {
    unowned let canvas: CoreGraphicsCanvasView

    init(canvas: CoreGraphicsCanvasView) {
        self.canvas = canvas
    }

    func hitTest(at point: CGPoint) -> UUID? {
        // This logic remains sound. We iterate through elements and give connections
        // a chance to return a more specific ID (an edge's ID) before falling back.
        for element in canvas.elements.reversed() { // NOTE: Reversed to hit topmost elements first

            // 1 — Check for a specific segment hit within a connection.
            if case .connection(let conn) = element,
               let edgeID = conn.hitSegmentID(at: point, tolerance: 5) {
                print(edgeID)
                return edgeID
            }

            // 2 — Fall back to hitting the element as a whole.
            // This now works perfectly for connections, as their hitTest method
            // checks all their constituent edges.
            if element.hitTest(point) {
                return element.id
            }
        }
        return nil
    }
    
    /// Returns the Pin that sits under `point` or nil.
    func pin(at point: CGPoint) -> Pin? {

        // 1 ─ stand-alone Pin elements -------------------------------------------------
        for element in canvas.elements {
            if case .pin(let pin) = element,
               pin.hitTest(point) {
                return pin
            }
        }

        // 2 ─ pins that are embedded inside a SymbolElement ---------------------------
        for element in canvas.elements {
            guard case .symbol(let symbol) = element else { continue }

            // go into the symbol's local space first
            let local = point /*.applying(symbol.transform.inverted())*/

            for pin in symbol.symbol.pins
            where pin.hitTest(local) {
                return pin
            }
        }

        // 3 ─ nothing hit -------------------------------------------------------------
        return nil
    }
}
