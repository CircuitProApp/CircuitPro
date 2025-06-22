import SwiftUI

func rotate1(point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
    let deltaX = point.x - center.x
    let deltaY = point.y - center.y
    let cosA = cos(angle)
    let sinA = sin(angle)
    return CGPoint(
        x: center.x + deltaX * cosA - deltaY * sinA,
        y: center.y + deltaX * sinA + deltaY * cosA
    )
}

func unrotate1(point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
    rotate1(point: point, around: center, by: -angle)
}
