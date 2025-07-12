//
//  CanvasHitTestController.swift
//  Circuit Pro_Tests
//
//  Created by Giorgi Tchelidze on 5/16/25.
//
import AppKit

// MARK: - CanvasHitTestController.swift
final class CanvasHitTestController {
    unowned let dataSource: CanvasHitTestControllerDataSource

    init(dataSource: CanvasHitTestControllerDataSource) {
        self.dataSource = dataSource
    }

    func hitTest(at point: CGPoint) -> UUID? {
        let tolerance = 5.0 / dataSource.magnificationForHitTesting()
        for element in dataSource.elementsForHitTesting().reversed() {
            // If we hit a connection, we want to check for a specific edge hit first.
            if case .connection(let conn) = element {
                let graphHit = conn.graph.hitTest(at: point, tolerance: tolerance)
                if case .edge(let edgeID, _, _) = graphHit {
                    return edgeID // Return the specific edge ID
                }
            }

            // Fall back to hitting the element as a whole.
            if element.hitTest(point) {
                return element.id
            }
        }
        return nil
    }

    func hitTestForConnection(at point: CGPoint) -> ConnectionHitTarget {
        let tolerance = 5.0 / dataSource.magnificationForHitTesting()
        for element in dataSource.elementsForHitTesting().reversed() {
            guard case .connection(let conn) = element else { continue }
            
            // Use the graph's enriched hit-test result
            let graphHit = conn.graph.hitTest(at: point, tolerance: tolerance)
            
            switch graphHit {
            case .vertex(let vertexID, let position, let type):
                return .vertex(vertexID: vertexID, onConnection: conn.id, position: position, type: type)
            case .edge(let edgeID, _, let orientation):
                // We use the original point for the edge `at` parameter, as it's more precise
                return .edge(edgeID: edgeID, onConnection: conn.id, at: point, orientation: orientation)
            case .emptySpace:
                continue
            }
        }
        return .emptySpace(point: point)
    }

    /// Returns the Pin that sits under `point` or nil.
    func pin(at point: CGPoint) -> Pin? {

        // 1 ─ stand-alone Pin elements -------------------------------------------------
        for element in dataSource.elementsForHitTesting() {
            if case .pin(let pin) = element,
               pin.hitTest(point) {
                return pin
            }
        }

        // 2 ─ pins that are embedded inside a SymbolElement ---------------------------
        for element in dataSource.elementsForHitTesting() {
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
