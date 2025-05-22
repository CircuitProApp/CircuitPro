import SwiftUI

func rotate(point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
    let deltaX = point.x - center.x
    let deltaY = point.y - center.y
    let cosA = cos(angle)
    let sinA = sin(angle)
    return CGPoint(
        x: center.x + deltaX * cosA - deltaY * sinA,
        y: center.y + deltaX * sinA + deltaY * cosA
    )
}

func unrotate(point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
    rotate(point: point, around: center, by: -angle)
}
