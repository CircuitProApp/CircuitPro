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
        for (id, rect) in pinLabelRects where rect.contains(point) {
            return id
        }
        for (id, rect) in pinNumberRects where rect.contains(point) {
            return id
        }
        for element in canvas.elements.reversed()
        where element.primitives.contains(where: { $0.systemHitTest(at: point) }) {
            return element.id
        }
        return nil
    }
}
