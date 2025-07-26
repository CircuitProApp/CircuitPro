import AppKit

/// Describes an object's visual representation for rendering.
/// Conforming types are also identifiable, allowing for selection tracking.
protocol Drawable: Identifiable where ID == UUID {
    /// Generates drawing parameters for the element's main body.
    func makeBodyParameters() -> [DrawingParameters]
    
    /// Generates drawing parameters for a context-aware selection halo.
    /// - Note: A default implementation is provided.
    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters?
    
    /// Provides the CGPath to be used for this element's halo.
    /// - Note: This is called by the default `makeHaloParameters` implementation.
    func makeHaloPath() -> CGPath?
}

// MARK: - Default Implementations
extension Drawable {
    
    /// The default implementation for drawing a selection halo.
    /// It checks if the element's ID is in the selection set, and if so,
    /// uses the path from `makeHaloPath()` to create the drawing parameters.
    ///
    /// Container types like `SymbolElement` that need more complex halo logic
    /// (e.g., showing halos for sub-selected children) should provide their own
    /// custom implementation of this method.
    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
        // The default behavior is to only show a halo if this specific element is selected.
        guard selectedIDs.contains(self.id) else { return nil }
        
        // Get the specific path for the halo from the conforming type.
        guard let path = makeHaloPath(), !path.isEmpty else { return nil }
        
        // Use a standard appearance for the halo.
        return DrawingParameters(
            path: path,
            lineWidth: 4.0, // A standard, visible width
            fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        )
    }
    
    /// A convenience override that allows calling `makeHaloParameters()` without any arguments.
    /// This is useful for contexts where selection is not relevant, and it simply
    /// calls the primary method with an empty selection set.
    func makeHaloParameters() -> DrawingParameters? {
        return self.makeHaloParameters(selectedIDs: [])
    }
    
    /// A default implementation of `makeHaloPath` that returns nil.
    /// This allows conforming types to only implement it if they want to use
    /// the default halo behavior. Types that provide a custom `makeHaloParameters`
    /// (like containers) do not need to implement this.
    func makeHaloPath() -> CGPath? {
        return nil
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
