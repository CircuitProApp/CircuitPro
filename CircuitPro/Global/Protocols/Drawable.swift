import AppKit

/// Describes an object's visual representation for both immediate-mode (Core Graphics)
/// and retained-mode (Core Animation) rendering.
protocol Drawable {

    // MARK: - Modern Drawing (Core Animation)
    func makeBodyParameters() -> [DrawingParameters]
    func makeHaloParameters() -> DrawingParameters?
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
