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
        let length = hypot(end.y - start.y, end.x - start.x)
        // The handles are defined in local space, as if the line were
        // horizontal and centered at (0,0).
        return [
            Handle(kind: .lineStart, position: CGPoint(x: -length / 2, y: 0)),
            Handle(kind: .lineEnd,   position: CGPoint(x:  length / 2, y: 0))
        ]
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to dragLocal: CGPoint,
        opposite oppWorld: CGPoint?
    ) {
        // The interaction provides the new handle position in the primitive's
        // local space. To update our model (which is based on world-space
        // points), we must convert this local point back to world space.
        
        // 1. Get the current world transform of the line.
        let currentPosition = self.position
        let currentRotation = self.rotation
        let transform = CGAffineTransform(translationX: currentPosition.x, y: currentPosition.y)
            .rotated(by: currentRotation)

        // 2. Convert the local drag point to a world point.
        let newWorldPoint = dragLocal.applying(transform)

        // 3. Update the appropriate endpoint.
        switch kind {
        case .lineStart:
            self.start = newWorldPoint
        case .lineEnd:
            self.end = newWorldPoint
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

