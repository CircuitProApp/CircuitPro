import AppKit

/// Describes an object's visual representation for both immediate-mode (Core Graphics)
/// and retained-mode (Core Animation) rendering.
protocol Drawable {
    /// Generates drawing parameters for the element's main body.
    func makeBodyParameters() -> [DrawingParameters]
    
    
    /// Generates drawing parameters for a context-aware selection halo.
    /// This method can inspect the full selection set to decide what to halo.
    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters?
}

// MARK: - Default Implementations
extension Drawable {
    /// CONVENIENCE: A simpler way to call the halo method when you know
    /// there is no selection. This is NOT a requirement.
    func makeHaloParameters() -> DrawingParameters? {
        // This calls the required method above with an empty set.
        return self.makeHaloParameters(selectedIDs: [])
    }
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
