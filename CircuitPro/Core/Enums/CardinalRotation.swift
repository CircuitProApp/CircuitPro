//
//  CardinalRotation.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

enum CardinalRotation: CGFloat, CaseIterable, Codable, Hashable {
    case east      = 0
    case northeast = 45
    case north     = 90
    case northwest = 135
    case west      = 180
    case southwest = 225
    case south     = 270
    case southeast = 315

    /// Radians, for use in CGAffineTransform and other Core Graphics functions.
    var radians: CGFloat {
        self.rawValue * .pi / 180
    }
    
    /// Unit vector pointing in the direction of the rotation.
    var direction: CGPoint {
        switch self {
        case .east:      return CGPoint(x: 1, y: 0)
        case .northeast: return CGPoint(x: 1, y: 1).normalized()
        case .north:     return CGPoint(x: 0, y: 1)
        case .northwest: return CGPoint(x: -1, y: 1).normalized()
        case .west:      return CGPoint(x: -1, y: 0)
        case .southwest: return CGPoint(x: -1, y: -1).normalized()
        case .south:     return CGPoint(x: 0, y: -1)
        case .southeast: return CGPoint(x: 1, y: -1).normalized()
        }
    }
    
    /// Snaps an arbitrary angle (in radians) to the nearest cardinal direction (90-degree increments).
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
    
    /// Snaps an arbitrary angle (in radians) to the nearest 45-degree increment.
    static func closestWithDiagonals(to angle: CGFloat) -> CardinalRotation {
        // 1. Convert radians to degrees in [0, 360) range.
        let degrees = angle * 180 / .pi
        let norm = ((degrees.truncatingRemainder(dividingBy: 360)) + 360)
                      .truncatingRemainder(dividingBy: 360)

        // 2. Snap to the nearest 45-degree increment.
        let snappedDegrees = round(norm / 45) * 45
        
        // 3. Initialize from raw value.
        return CardinalRotation(rawValue: snappedDegrees) ?? .east // Default to East
    }
}
