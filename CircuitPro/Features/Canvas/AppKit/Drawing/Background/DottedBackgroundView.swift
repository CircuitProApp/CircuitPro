// CircuitPro/Features/Canvas/AppKit/Drawing/Background/DottedBackgroundView.swift
import AppKit

final class DottedBackgroundView: NSView {

    // MARK: - Layers
    private let majorGridLayer = CAShapeLayer()
    private let minorGridLayer = CAShapeLayer()

    // MARK: - Public Properties
    var unitSpacing: CGFloat = 10.0 {
        didSet {
            // A layout pass is needed to recalculate grid paths.
            needsLayout = true
        }
    }

    var magnification: CGFloat = 1.0 {
        didSet {
            // A layout pass is needed to recalculate grid paths.
            needsLayout = true
        }
    }
    
    var gridOrigin: CGPoint = .zero {
        didSet {
            guard gridOrigin != oldValue else { return }
            needsLayout = true
        }
    }
    
    // MARK: - View Lifecycle & Configuration
    
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        guard let layer = self.layer else { return }
        layer.masksToBounds = true
        
        // 1. Setup Layer Hierarchy
        layer.addSublayer(majorGridLayer)
        layer.addSublayer(minorGridLayer)
        
        // 2. Configure Layer Colors
        majorGridLayer.fillColor = NSColor.gray.withAlphaComponent(1.0).cgColor
        minorGridLayer.fillColor = NSColor.gray.withAlphaComponent(0.5).cgColor
    }

    override func layout() {
        super.layout()
        // The frame of sublayers should match the bounds of this view's layer.
        majorGridLayer.frame = layer?.bounds ?? .zero
        minorGridLayer.frame = layer?.bounds ?? .zero
        updateGrid()
    }
    
    override var wantsUpdateLayer: Bool {
        return true
    }

    override func updateLayer() {
        // Set the contents scale for our layers to ensure high-resolution rendering.
        let scale = window?.backingScaleFactor ?? 1.0
        majorGridLayer.contentsScale = scale
        minorGridLayer.contentsScale = scale
    }

    // MARK: - Drawing Logic
    private func updateGrid() {
        
        if magnification < 0.35 {
            majorGridLayer.path = nil
            minorGridLayer.path = nil
            return
        }
        
        // 1. Calculate the true drawing area.
        let drawingRect = self.bounds.intersection(self.visibleRect)

        guard !drawingRect.isEmpty else {
            majorGridLayer.path = nil
            minorGridLayer.path = nil
            return
        }
        
        // 2. Calculate Drawing Parameters
        let spacing = adjustedSpacing()
        let dotRadius = (1.0 / max(magnification, 1.0))
        
        let majorPath = CGMutablePath()
        let minorPath = CGMutablePath()

        // 3. Set loop boundaries based on the precise `drawingRect`.
        let startX = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minX, offset: gridOrigin.x)
        let startY = previousMultiple(of: spacing, beforeOrEqualTo: drawingRect.minY, offset: gridOrigin.y)
        
        let endX = drawingRect.maxX
        let endY = drawingRect.maxY

        // 4. Generate Dot Paths only within the calculated rectangle.
        var currentY = startY
        while currentY <= endY {
            let yGridIndex = Int(round((currentY - gridOrigin.y) / spacing))
            let yIsMajor = (yGridIndex % 10 == 0)

            var currentX = startX
            while currentX <= endX {
                let xGridIndex = Int(round((currentX - gridOrigin.x) / spacing))
                let isMajor = yIsMajor || (xGridIndex % 10 == 0)
                
                let dotRect = CGRect(x: currentX - dotRadius, y: currentY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)

                if isMajor {
                    majorPath.addEllipse(in: dotRect)
                } else {
                    minorPath.addEllipse(in: dotRect)
                }
                currentX += spacing
            }
            currentY += spacing
        }
        
        // 5. Assign Paths to Layers
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        majorGridLayer.path = majorPath
        minorGridLayer.path = minorPath
        CATransaction.commit()
    }

    // MARK: - Helpers
    private func previousMultiple(of step: CGFloat, beforeOrEqualTo value: CGFloat, offset: CGFloat = 0) -> CGFloat {
        guard step > 0 else { return value }
        return floor((value - offset) / step) * step + offset
    }

    private func adjustedSpacing() -> CGFloat {
        switch unitSpacing {
        case 5:
            return magnification < 2.0 ? 10 : 5
        case 2.5:
            if magnification < 2.0 { return 10 }
            else if magnification < 3.0 { return 5 }
            else { return 2.5 }
        case 1:
            if magnification < 2.5 { return 8 }
            else if magnification < 5.0 { return 4 }
            else if magnification < 10 { return 2 }
            else { return 1 }
        default:
            return unitSpacing
        }
    }
}
