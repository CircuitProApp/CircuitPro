import SwiftUI

enum CardinalRotation: CGFloat, CaseIterable, Codable, Hashable {
    case deg0 = 0
    case deg90 = 90
    case deg180 = 180
    case deg270 = 270

    var radians: CGFloat {
        CGFloat(rawValue) * .pi / 180
    }
}

extension CardinalRotation {
    /// Unit vector in the direction of this rotation.
    var direction: CGPoint {
        switch self {
        case .deg0:   return CGPoint(x: -1, y: 0) // West
        case .deg90:  return CGPoint(x: 0, y: 1) // North
        case .deg180: return CGPoint(x: 1, y: 0) // East
        case .deg270: return CGPoint(x: 0, y: -1) // South
        }
    }
}

extension CardinalRotation {
    /// Snaps an arbitrary angle (radians, math coords) to the
    /// nearest of the four cardinals, compensating for the fact
    /// that we treat 0° as **West** and 180° as **East**.
    static func closest(to angle: CGFloat) -> CardinalRotation {
        // radians → [0 , 360) in mathematical convention (0° = +X)
        let degrees = angle * 180 / .pi
        let norm    = ((degrees.truncatingRemainder(dividingBy: 360)) + 360)
                      .truncatingRemainder(dividingBy: 360)

        // snap to the nearest 90-degree stop
        let snap = (round(norm / 90) * 90).truncatingRemainder(dividingBy: 360)

        switch Int(snap) {
        case 0:   return .deg180   // mouse → E  → our “East” enum
        case 90:  return .deg90    // mouse → N
        case 180: return .deg0     // mouse → W
        case 270: return .deg270   // mouse → S
        default:  return .deg0     // fallback (shouldn’t happen)
        }
    }
}
