import CoreGraphics
import AppKit

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension CGColor {
    func applyingOpacity(_ opacity: CGFloat) -> CGColor {
        let base = NSColor(cgColor: self) ?? NSColor.clear
        return base.withAlphaComponent((base.alphaComponent * opacity).clamped(to: 0...1)).cgColor
    }
}
