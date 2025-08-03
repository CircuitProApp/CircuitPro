import SwiftUI

extension CGPoint {
    /// Rotates the point around a given center by a specified angle in radians.
    /// - Parameters:
    ///   - center: The point to rotate around. Defaults to `.zero`.
    ///   - angle: The angle in radians.
    /// - Returns: The new, rotated point.
    func rotated(around center: CGPoint = .zero, by angle: CGFloat) -> CGPoint {
        let deltaX = self.x - center.x
        let deltaY = self.y - center.y
        let cosA = cos(angle)
        let sinA = sin(angle)
        return CGPoint(
            x: center.x + deltaX * cosA - deltaY * sinA,
            y: center.y + deltaX * sinA + deltaY * cosA
        )
    }
}
