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
        for element in canvas.elements.reversed()           // top-most first
        where element.systemHitTest(at: point) {
            return element.id
        }

        // 3. Nothing hit
        return nil
    }
}
