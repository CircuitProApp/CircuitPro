//
//  WorkbenchHitTestService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import AppKit

/// Performs detailed hit-testing for all interactive items on the workbench.
struct WorkbenchHitTestService {

    /// Finds the most specific interactive element at a given point on the canvas.
    ///
    /// This method checks elements in reverse rendering order (top-most first) to ensure
    /// the correct element is picked. It checks connections first, then standard canvas elements.
    ///
    /// - Parameters:
    ///   - point: The point to test, in world coordinates.
    ///   - elements: The array of all `CanvasElement` items on the workbench.
    ///   - netlist: The `NetList` containing all connection elements.
    ///   - magnification: The current zoom level of the canvas, used to adjust hit tolerance.
    /// - Returns: A `CanvasHitTarget` describing the hit, or `nil` if nothing was hit.
    func hitTest(
        at point: CGPoint,
        elements: [CanvasElement],
        netlist: NetList,
        magnification: CGFloat
    ) -> CanvasHitTarget? {
        let tolerance = 5.0 / magnification

        // 1. Check connections first, as they often sit "on top" of pins.
        for connection in netlist.connections.reversed() {
            if let hit = connection.hitTest(point, tolerance: tolerance) {
                return hit
            }
        }

        // 2. Check standard canvas elements.
        for element in elements.reversed() {
            if let hit = element.hitTest(point, tolerance: tolerance) {
                return hit
            }
        }

        // 3. If nothing was hit, return nil. The caller can interpret this as .emptySpace.
        return nil
    }
}
