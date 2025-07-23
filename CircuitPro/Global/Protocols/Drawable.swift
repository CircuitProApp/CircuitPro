import AppKit

/// Describes an object's visual representation for both immediate-mode (Core Graphics)
/// and retained-mode (Core Animation) rendering.
protocol Drawable {
    
    // MARK: - Legacy Drawing (Core Graphics)
    func drawBody(in ctx: CGContext)

    // MARK: - Modern Drawing (Core Animation)
    func makeBodyParameters() -> [DrawingParameters]
    func makeHaloParameters() -> DrawingParameters?
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
    /// been updated to the new `makeBodyParameters` system.
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
