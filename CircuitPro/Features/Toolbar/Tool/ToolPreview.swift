import AppKit

/// Describes the appearance of a tool's preview drawing.
struct ToolPreview {
    let path: CGPath
    let fillColor: CGColor?
    let strokeColor: CGColor?
    let lineWidth: CGFloat
    let lineDashPattern: [NSNumber]?
    let lineCap: CAShapeLayerLineCap
    let lineJoin: CAShapeLayerLineJoin

    init(path: CGPath,
         fillColor: CGColor? = nil,
         strokeColor: CGColor? = .black,
         lineWidth: CGFloat = 1.0,
         lineDashPattern: [NSNumber]? = nil,
         lineCap: CAShapeLayerLineCap = .round,
         lineJoin: CAShapeLayerLineJoin = .round)
    {
        self.path = path
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.lineDashPattern = lineDashPattern
        self.lineCap = lineCap
        self.lineJoin = lineJoin
    }
}
