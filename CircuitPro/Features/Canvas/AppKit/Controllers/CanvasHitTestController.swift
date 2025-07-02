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
        for element in canvas.elements {

            // 1 ─ give connection elements a chance to return a *segment* id
            if case .connection(let conn) = element,
               let segID = conn.hitSegmentID(at: point, tolerance: 5) {
                return segID
            }

            // 2 ─ fall back to the element as a whole
            if element.hitTest(point) { return element.id }
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
