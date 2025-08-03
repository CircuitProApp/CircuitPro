import AppKit

/// Data needed for a single drawing pass.
struct DrawingParameters {
    let path: CGPath
    var lineWidth: CGFloat
    var fillColor: CGColor?
    var strokeColor: CGColor? = NSColor.systemBlue.cgColor
    var lineDashPattern: [NSNumber]?
    var lineCap: CAShapeLayerLineCap = .round
    var lineJoin: CAShapeLayerLineJoin = .round
    var fillRule: CAShapeLayerFillRule = .nonZero
}

