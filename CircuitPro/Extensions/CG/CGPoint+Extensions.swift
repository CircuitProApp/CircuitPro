import SwiftUI

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
