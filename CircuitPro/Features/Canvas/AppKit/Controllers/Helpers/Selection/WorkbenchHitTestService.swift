//
//  WorkbenchHitTestService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import AppKit

/// Performs hit-testing for regular canvas elements
/// (symbols, pads, pins, primitives).  No net / connection
/// logic is included in this clean-sheet version.
struct WorkbenchHitTestService {

    // 1. Element under the cursor
    func hitTest(in elements: [CanvasElement],
                 at point: CGPoint,
                 magnification: CGFloat) -> UUID? {

        let tol = 5.0 / magnification
        for element in elements.reversed() {
            if element.hitTest(point, tolerance: tol) {
                return element.id
            }
        }
        return nil
    }

    // 2. Pin under the cursor (stand-alone or inside a symbol)
    func pin(in elements: [CanvasElement],
             at point: CGPoint) -> Pin? {

        // Stand-alone pins
        if let p = elements.first(where: {
            if case .pin(let pin) = $0 { return pin.hitTest(point) }
            return false
        }), case .pin(let pin) = p {
            return pin
        }

        // Pins inside a symbol
        for element in elements {
            guard case .symbol(let sym) = element else { continue }
            if let pin = sym.symbol.pins.first(where: { $0.hitTest(point) }) {
                return pin
            }
        }
        return nil
    }
}
