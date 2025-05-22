import SwiftUI

extension CGPoint {

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }

    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
   
}

extension CGPoint {
    init(_ sdPoint: SDPoint) {
        self.init(x: sdPoint.x, y: sdPoint.y)
    }
}


extension CGPoint {
  var asSDPoint: SDPoint { SDPoint(self) }
}

extension CGPoint {
  /// Euclidean distance between two points
  func distance(to other: CGPoint) -> CGFloat {
    hypot(other.x - x, other.y - y)
  }
}
