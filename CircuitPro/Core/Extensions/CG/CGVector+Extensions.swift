import CoreGraphics

extension CGVector {
    /// Rotates the vector by a given angle in radians.
    func rotated(by angle: CGFloat) -> CGVector {
        let newDx = self.dx * cos(angle) - self.dy * sin(angle)
        let newDy = self.dx * sin(angle) + self.dy * cos(angle)
        return CGVector(dx: newDx, dy: newDy)
    }
}
