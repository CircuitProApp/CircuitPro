import AppKit

/// Describes an object's visual representation for rendering.
/// Conforming types are also identifiable, allowing for selection tracking.
protocol Drawable: Identifiable where ID == UUID {
    /// Generates a list of high-level drawing commands that describe the element's appearance.
    func makeDrawingPrimitives() -> [DrawingPrimitive]
    
    /// Provides the CGPath to be used for this element's selection halo.
    /// The renderer will be responsible for styling this path.
    func makeHaloPath() -> CGPath?
}

// MARK: - Helpers
extension CAShapeLayerLineCap {
    func toCGLineCap() -> CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        default: return .round
        }
    }
}

extension CAShapeLayerLineJoin {
    func toCGLineJoin() -> CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        default: return .round
        }
    }
}
