import AppKit

/// Describes an object's visual representation for both immediate-mode (Core Graphics)
/// and retained-mode (Core Animation) rendering.
protocol Drawable {
    
    // MARK: - Legacy Drawing (Core Graphics)
    /// Paints the normal appearance of the object into a graphics context.
    /// Note: This is bridged to the new layer-based system by default.
    func drawBody(in ctx: CGContext)

    // MARK: - Modern Drawing (Core Animation)
    /// Generates the declarative parameters for the main body of the object.
    /// - Returns: An array of `DrawingParameters` structs, one for each `CAShapeLayer` required.
    func makeBodyParameters() -> [DrawingParameters]

    // MARK: - Selection Highlighting
    /// An optional outline path that should glow when the object is selected.
    /// For composite objects, this should return a single unified path.
    /// - Returns: A `CGPath` representing the highlightable outline, or `nil`.
    func selectionPath() -> CGPath?
}

extension Drawable {
    
    /// Default implementation that provides legacy Core Graphics drawing for any type
    /// that conforms to the new `makeBodyParameters()` method.
    func drawBody(in ctx: CGContext) {
        let parameters = makeBodyParameters()
        
        for p in parameters {
            ctx.saveGState()
            
            ctx.addPath(p.path)
            
            if let fillColor = p.fillColor {
                ctx.setFillColor(fillColor)
                ctx.fillPath()
            }
            
            if let strokeColor = p.strokeColor {
                ctx.setStrokeColor(strokeColor)
                ctx.setLineWidth(p.lineWidth)
                ctx.setLineCap(p.lineCap.toCGLineCap())
                ctx.setLineJoin(p.lineJoin.toCGLineJoin())
                
                if let dash = p.lineDashPattern {
                    let lengths = dash.map { CGFloat($0.doubleValue) }
                    ctx.setLineDash(phase: 0, lengths: lengths)
                }
                
                ctx.strokePath()
            }
            
            ctx.restoreGState()
        }
    }

    /// Default implementation that will intentionally crash for types that have not
    /// yet been migrated to the new `makeBodyParameters` system. This ensures
    /// all `Drawable`s explicitly support layer-based rendering.
    func makeBodyParameters() -> [DrawingParameters] {
        fatalError("\(type(of: self)) has not been updated to support layer-based rendering. Please implement makeBodyParameters().")
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
