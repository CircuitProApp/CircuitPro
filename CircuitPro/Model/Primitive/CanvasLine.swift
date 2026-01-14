//
//  CanvasLine.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import CoreGraphics
import Foundation

struct CanvasLine: CanvasPrimitive {

    let id: UUID
    var length: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat

    // A line can't be filled, but the protocol requires this.
    // We could consider a protocol composition approach later to refine this.
    var filled: Bool = false

    var layerId: UUID?

    var startPoint: CGPoint {
         get {
             // Calculate the start point from the center, rotation, and half-length.
             let halfLength = length / 2
             let dx = halfLength * cos(rotation)
             let dy = halfLength * sin(rotation)
             return CGPoint(x: position.x - dx, y: position.y - dy)
         }
         set {
             // When the start point is changed, use the current end point as the anchor
             // and recalculate all fundamental properties.
             let end = self.endPoint // Capture the current end point before changing properties.
             let newStart = newValue

             let dx = end.x - newStart.x
             let dy = end.y - newStart.y

             self.length = hypot(dx, dy)
             self.rotation = atan2(dy, dx)
             self.position = CGPoint(x: (newStart.x + end.x) / 2, y: (newStart.y + end.y) / 2)
         }
     }

     /// A computed property that calculates the line's end point in world coordinates.
     /// Setting this property will recalculate the line's position, rotation, and length
     /// based on the existing start point.
     var endPoint: CGPoint {
         get {
             // Calculate the end point from the center, rotation, and half-length.
             let halfLength = length / 2
             let dx = halfLength * cos(rotation)
             let dy = halfLength * sin(rotation)
             return CGPoint(x: position.x + dx, y: position.y + dy)
         }
         set {
             // When the end point is changed, use the current start point as the anchor
             // and recalculate all fundamental properties.
             let start = self.startPoint // Capture the current start point.
             let newEnd = newValue

             let dx = newEnd.x - start.x
             let dy = newEnd.y - start.y

             self.length = hypot(dx, dy)
             self.rotation = atan2(dy, dx)
             self.position = CGPoint(x: (start.x + newEnd.x) / 2, y: (start.y + newEnd.y) / 2)
         }
     }

    init(id: UUID = UUID(), start: CGPoint, end: CGPoint, strokeWidth: CGFloat, layerId: UUID?) {
        self.id = id
        self.strokeWidth = strokeWidth
        self.layerId = layerId

        // Perform the calculation to set the fundamental properties.
        let dx = end.x - start.x
        let dy = end.y - start.y

        self.length = hypot(dx, dy)
        self.rotation = atan2(dy, dx)
        self.position = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }

}

extension CanvasLine: CanvasItem {}
