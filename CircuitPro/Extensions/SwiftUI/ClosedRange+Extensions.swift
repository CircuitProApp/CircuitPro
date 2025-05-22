import SwiftUI

extension ClosedRange where Bound: Comparable {
    func clamp(_ value: Bound) -> Bound {
        return Swift.min(Swift.max(lowerBound, value), upperBound)
    }
}
