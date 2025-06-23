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


        // 2. Defer to each element’s own hit-test logic
        for element in canvas.elements.reversed() where element.hitTest(point) {
            return element.id
        }

        // 3. Nothing hit
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
