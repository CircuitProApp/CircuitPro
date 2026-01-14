//
//  CanvasLine.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct CanvasLine: CanvasPrimitive {

    let id: UUID
    var length: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var strokeWidth: CGFloat
    var color: SDColor?

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

    func handles() -> [CanvasHandle] {
        // The handles are defined in local space, as if the line were
        // horizontal and centered at (0,0).
        let halfLength = length / 2
        return [
            CanvasHandle(kind: .lineStart, position: CGPoint(x: -halfLength, y: 0)),
            CanvasHandle(kind: .lineEnd,   position: CGPoint(x:  halfLength, y: 0))
        ]
    }

    mutating func updateHandle(
        _ kind: CanvasHandle.Kind,
        to dragLocal: CGPoint,
        opposite oppLocal: CGPoint?
    ) {
        guard let oppLocal = oppLocal else { return }

        // The method receives points in the line's original local space.
        // To robustly calculate the new geometry, we first need to convert these
        // local points back into world space using the line's current transform.
        let oldTransform = CGAffineTransform(translationX: self.position.x, y: self.position.y)
            .rotated(by: self.rotation)

        // Determine which point is the new start and which is the new end based
        // on the handle that was dragged.
        let newStartWorld: CGPoint
        let newEndWorld: CGPoint

        if kind == .lineStart {
            newStartWorld = dragLocal.applying(oldTransform)
            newEndWorld = oppLocal.applying(oldTransform)
        } else {
            newStartWorld = oppLocal.applying(oldTransform)
            newEndWorld = dragLocal.applying(oldTransform)
        }

        // Now that we have the definitive start and end points in world space,
        // we can use the same logic as our convenience initializer to recalculate
        // all fundamental properties from scratch. This is the most reliable approach.
        let dx = newEndWorld.x - newStartWorld.x
        let dy = newEndWorld.y - newStartWorld.y

        self.length = hypot(dx, dy)
        self.rotation = atan2(dy, dx)
        self.position = CGPoint(x: (newStartWorld.x + newEndWorld.x) / 2, y: (newStartWorld.y + newEndWorld.y) / 2)
    }

    func makePath() -> CGPath {
        // Create a simple horizontal line of the correct length,
        // centered at the origin (0,0). The renderer will apply the
        // position and rotation.
        let halfLength = length / 2
        let localStart = CGPoint(x: -halfLength, y: 0)
        let localEnd = CGPoint(x: halfLength, y: 0)

        let path = CGMutablePath()
        path.move(to: localStart)
        path.addLine(to: localEnd)

        return path
    }
}

extension CanvasLine: CanvasItem {}
