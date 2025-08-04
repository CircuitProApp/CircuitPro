//
//  LinePrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

struct LinePrimitive: GraphicPrimitive {

    let id: UUID
    var start: CGPoint
    var end: CGPoint
    var strokeWidth: CGFloat
    var filled: Bool = false // A line can't be filled, but protocol might require it.
    var color: SDColor

    /// The position is the center point of the line.
    var position: CGPoint {
        get {
            CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
        }
        set {
            let currentPos = self.position
            let deltaX = newValue.x - currentPos.x
            let deltaY = newValue.y - currentPos.y
            start.x += deltaX
            start.y += deltaY
            end.x += deltaX
            end.y += deltaY
        }
    }

    /// Rotation is a computed property, derived from the start and end points.
    /// It is not stored, which was the source of previous bugs.
    var rotation: CGFloat {
        get {
            atan2(end.y - start.y, end.x - start.x)
        }
        set {
            // Setting rotation on a line primitive is complex and not
            // a standard user interaction. We rotate the line around its
            // center point.
            let center = self.position
            let currentAngle = self.rotation
            let angleDelta = newValue - currentAngle
            start = start.rotated(around: center, by: angleDelta)
            end = end.rotated(around: center, by: angleDelta)
        }
    }

    func handles() -> [Handle] {
        [
            Handle(kind: .lineStart, position: start),
            Handle(kind: .lineEnd, position: end)
        ]
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to dragWorld: CGPoint,
        opposite oppWorld: CGPoint?
    ) {
        // The drag gesture provides the new snapped position for the handle
        // being dragged. We just need to update the corresponding point.
        // The other point of the line remains fixed at its current position.
        switch kind {
        case .lineStart:
            self.start = dragWorld
        case .lineEnd:
            self.end = dragWorld
        default:
            break
        }
    }

    func makePath() -> CGPath {
        // Calculate the total length of the line.
        let length = hypot(end.x - start.x, end.y - start.y)
        
        // THE FIX: Create a simple horizontal line of the correct length,
        // centered at the origin (0,0).
        let localStart = CGPoint(x: -length / 2, y: 0)
        let localEnd = CGPoint(x: length / 2, y: 0)
        
        let path = CGMutablePath()
        path.move(to: localStart)
        path.addLine(to: localEnd)
        
        return path
    }
}

