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

    var pinLabelRects: [UUID: CGRect] = [:]
    var pinNumberRects: [UUID: CGRect] = [:]

    init(canvas: CoreGraphicsCanvasView) {
        self.canvas = canvas
    }

    func updateRects() {
        pinLabelRects.removeAll()
        pinNumberRects.removeAll()
    }

    func hitTest(at point: CGPoint) -> UUID? {
        // 1. Text rectangles on pins have highest priority
        for (id, rect) in pinLabelRects  where rect.contains(point) { return id }
        for (id, rect) in pinNumberRects where rect.contains(point) { return id }

        // 2. Defer to each element’s own hit-test logic
        for element in canvas.elements.reversed() where element.systemHitTest(at: point) {
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
               pin.systemHitTest(at: point) {
                return pin
            }
        }

        // 2 ─ pins that are embedded inside a SymbolElement ---------------------------
        for element in canvas.elements {
            guard case .symbol(let symbol) = element else { continue }

            // go into the symbol's local space first
            let local = point.applying(symbol.transform.inverted())

            for pin in symbol.symbol.pins
            where pin.systemHitTest(at: local) {
                return pin
            }
        }

        // 3 ─ nothing hit -------------------------------------------------------------
        return nil
    }
}
