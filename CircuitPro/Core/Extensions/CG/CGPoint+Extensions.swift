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
    
    func normalized() -> CGPoint {
        let length = sqrt(x * x + y * y)
        guard length > 0 else { return .zero }
        return CGPoint(x: x / length, y: y / length)
    }
}
