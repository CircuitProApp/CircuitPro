//
//  WorkbenchHitTestService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//

import AppKit

struct WorkbenchHitTestService {

    // 1. Element or edge under the cursor
    func hitTest(in elements: [CanvasElement],
                 at point: CGPoint,
                 magnification: CGFloat) -> UUID? {

        let tol = 5.0 / magnification
        for element in elements.reversed() {

            if case .connection(let conn) = element {
                let gHit = conn.graph.hitTest(at: point, tolerance: tol)
                if case .edge(let edgeID, _, _) = gHit { return edgeID }
            }

            if element.hitTest(point) { return element.id }
        }
        return nil
    }

    // 2. Rich hit-test result for the connection tool
    func hitTestForConnection(in elements: [CanvasElement],
                              at point: CGPoint,
                              magnification: CGFloat) -> ConnectionHitTarget {

        let tol = 5.0 / magnification
        for element in elements.reversed() {
            guard case .connection(let conn) = element else { continue }

            switch conn.graph.hitTest(at: point, tolerance: tol) {
            case .vertex(let vID, let pos, let type):
                return .vertex(vertexID: vID, onConnection: conn.id,
                               position: pos, type: type)
            case .edge(let eID, _, let orientation):
                return .edge(edgeID: eID, onConnection: conn.id,
                             at: point, orientation: orientation)
            case .emptySpace:
                continue
            }
        }
        return .emptySpace(point: point)
    }

    // 3. Pin under the cursor (either stand-alone or inside a symbol)
    func pin(in elements: [CanvasElement],
             at point: CGPoint) -> Pin? {

        // stand-alone pins
        if let p = elements.first(where: {
            if case .pin(let pin) = $0 { return pin.hitTest(point) }
            return false
        }), case .pin(let pin) = p {
            return pin
        }

        // pins inside a symbol
        for element in elements {
            guard case .symbol(let sym) = element else { continue }
            let local = point
            if let pin = sym.symbol.pins.first(where: { $0.hitTest(local) }) {
                return pin
            }
        }
        return nil
    }
}
