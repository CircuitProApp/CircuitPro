import SwiftUI

enum CardinalRotation: CGFloat, CaseIterable, Codable, Hashable {
    // Cases are now named by their direction for clarity.
    // Raw values now match standard mathematical angles (0° is East).
    case east   = 0
    case north  = 90
    case west   = 180
    case south  = 270

    /// Radians, for use in CGAffineTransform and other Core Graphics functions.
    var radians: CGFloat {
        self.rawValue * .pi / 180
    }
    
    /// Unit vector pointing in the direction of the rotation.
    var direction: CGPoint {
        switch self {
        case .east:   return CGPoint(x: 1, y: 0)
        case .west:   return CGPoint(x: -1, y: 0)
        case .north:  return CGPoint(x: 0, y: 1)
        case .south:  return CGPoint(x: 0, y: -1)
        }
    }
    
    /// Snaps an arbitrary angle (in radians) to the nearest cardinal direction.
    static func closest(to angle: CGFloat) -> CardinalRotation {
        // 1. Convert radians to degrees in [0, 360) range.
        let degrees = angle * 180 / .pi
        let norm = ((degrees.truncatingRemainder(dividingBy: 360)) + 360)
                      .truncatingRemainder(dividingBy: 360)

        // 2. Snap to the nearest 90-degree increment.
        let snappedDegrees = round(norm / 90) * 90
        
        // 3. Directly initialize from the standard raw value. This is now simple and clear.
        return CardinalRotation(rawValue: snappedDegrees) ?? .east // Default to East
    }
}
