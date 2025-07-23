import AppKit
import CoreText

extension Pin: Drawable {
    
    // MARK: - Drawing Parameters
    
    func makeBodyParameters() -> [DrawingParameters] {
        var allParameters: [DrawingParameters] = []

        // 1. Add parameters for the geometric primitives.
        let primitiveParams = self.primitives.flatMap { $0.makeBodyParameters() }
        allParameters.append(contentsOf: primitiveParams)
        
        // 2. Add parameters for the pin number.
        if showNumber {
            var (path, transform) = numberLayout()
            if let finalPath = path.copy(using: &transform) {
                allParameters.append(DrawingParameters(
                    path: finalPath,
                    lineWidth: 0,
                    fillColor: NSColor.systemBlue.cgColor,
                    strokeColor: nil
                ))
            }
        }
        
        // 3. Add parameters for the pin label.
        if showLabel && name.isNotEmpty {
            var (path, transform) = labelLayout()
            if let finalPath = path.copy(using: &transform) {
                allParameters.append(DrawingParameters(
                    path: finalPath,
                    lineWidth: 0,
                    fillColor: NSColor.systemBlue.cgColor,
                    strokeColor: nil
                ))
            }
        }
        
        return allParameters
    }
    
    func makeHaloParameters() -> DrawingParameters? {
           let haloWidth: CGFloat = 4.0
           let textFattenAmount: CGFloat = 1.0 // A small width to fill in the text for the halo
           let outline = CGMutablePath()
           
           // 1. Add primitives to the outline.
           primitives.forEach { outline.addPath($0.makePath()) }
           
           // 2. Add pin number to the outline.
           if showNumber {
               var (path, transform) = numberLayout()
               if let transformedPath = path.copy(using: &transform) {
                   let fattedText = transformedPath.copy(strokingWithWidth: textFattenAmount, lineCap: .round, lineJoin: .round, miterLimit: 1)
                   outline.addPath(fattedText)
               }
           }
           
           // 3. Add pin label to the outline.
           if showLabel && name.isNotEmpty {
               var (path, transform) = labelLayout()
               // Apply the same fix for the label.
               if let transformedPath = path.copy(using: &transform) {
                   let fattedText = transformedPath.copy(strokingWithWidth: textFattenAmount, lineCap: .round, lineJoin: .round, miterLimit: 1)
                   outline.addPath(fattedText)
               }
           }
           
           guard !outline.isEmpty else { return nil }
           
           // 4. Return parameters to STROKE the final unified outline path.
           // Because the text paths are now solid blobs, the entire halo will be continuous.
           return DrawingParameters(
               path: outline,
               lineWidth: haloWidth,
               fillColor: nil,
               strokeColor: NSColor.systemBlue.withAlphaComponent(0.3).cgColor
           )
       }

    // MARK: - Layout Calculations
    func labelLayout() -> (path: CGPath, transform: CGAffineTransform) {
        let font = NSFont.systemFont(ofSize: 10)
        let pad: CGFloat = 4

        // The canonical text path at (0,0) and get its true bounds.
        let textPath = self.pathForText(name, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        
        var transform: CGAffineTransform

        switch cardinalRotation {
        case .west: // Pin points left. Anchor is middle-right of text box.
            let anchor = CGPoint(x: trueBounds.maxX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x - pad, y: legStart.y)
            transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)

        case .east: // Pin points right. Anchor is middle-left of text box.
            let anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x + pad, y: legStart.y)
            transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)
        
        case .north: // Pin points top. Anchor is middle-left of text box.
            let angle = CGFloat.pi / 2 // 90 degrees CCW
            let rotation = CGAffineTransform(rotationAngle: angle)
            
            let anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x, y: legStart.y + pad)
            
            let rotatedAnchor = anchor.applying(rotation)
            
            let translation = CGAffineTransform(translationX: target.x - rotatedAnchor.x, y: target.y - rotatedAnchor.y)
            
            transform = rotation.concatenating(translation)
        
        case .south: // Pin points down. Anchor is middle-right of text box.
            let angle = CGFloat.pi / 2 // 90 degrees CCW
            let rotation = CGAffineTransform(rotationAngle: angle)
            
            let anchor = CGPoint(x: trueBounds.maxX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x, y: legStart.y - pad)
            
            let rotatedAnchor = anchor.applying(rotation)
            
            let translation = CGAffineTransform(translationX: target.x - rotatedAnchor.x, y: target.y - rotatedAnchor.y)
            
            transform = rotation.concatenating(translation)
        }
        
        return (textPath, transform)
    }

    func numberLayout() -> (path: CGPath, transform: CGAffineTransform) {
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let pad: CGFloat = 3
        let text = "\(number)"
        
        let textPath = self.pathForText(text, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        
        let mid = CGPoint(x: (position.x + legStart.x) / 2, y: (position.y + legStart.y) / 2)
        
        let targetPos: CGPoint
        // UPDATED: Switch now uses semantic case names for clarity.
        switch cardinalRotation {
        case .east, .west: // Horizontal pins
            targetPos = CGPoint(x: mid.x - trueBounds.width / 2, y: mid.y + pad)
        case .north: // Pin points up, text is to the left
            targetPos = CGPoint(x: mid.x + pad + trueBounds.width, y: mid.y - trueBounds.height / 2)
        case .south: // Pin points down, text is to the right
            targetPos = CGPoint(x: mid.x + pad, y: mid.y - trueBounds.height / 2)
        }
        
        let transform = CGAffineTransform(translationX: targetPos.x - trueBounds.minX, y: targetPos.y - trueBounds.minY)
        return (textPath, transform)
    }

    /// Generates a single, simplified `DrawingParameters` object suitable for a tool preview.
    /// This combines the essential geometric primitives into one path.
    func makePreviewDrawingParameters() -> DrawingParameters? {
        // 1. Create a single path to hold all visible parts of the preview.
        let combinedPath = CGMutablePath()
        
        // 2. Add the geometric primitives (circle and line).
        self.primitives.forEach { combinedPath.addPath($0.makePath()) }

        // 3. Add the transformed pin number path.
        if showNumber {
            // `addPath` takes `transform` as a non-mutating parameter.
            let (path, transform) = numberLayout()
            combinedPath.addPath(path, transform: transform)
        }

        // 5. If the path is empty, there's nothing to preview.
        guard !combinedPath.isEmpty else { return nil }
        
        // 6. We must return a single drawing style. Stroking the unified path is the best
        //    compromise. The text will appear as a hollow outline, but all parts will be visible.
        guard let styleSource = self.primitives.first else { return nil }
        
        return DrawingParameters(
            path: combinedPath,
            lineWidth: 1, // Use the pin's standard line width
            fillColor: nil,                     // Nothing is filled
            strokeColor: styleSource.color.cgColor,  // Everything is stroked with the pin color
            lineCap: .round,
            lineJoin: .round
        )
    }
    /// Helper for converting a string to its raw vector CGPath at the origin (0,0).
    private func pathForText(_ string: String, font: NSFont) -> CGPath {
        let attrString = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attrString)
        let composite = CGMutablePath()
        
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return composite }
        
        for run in runs {
            let runFont = unsafeBitCast(CFDictionaryGetValue(CTRunGetAttributes(run), Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()), to: CTFont.self)
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            
            CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, count), &positions)
            
            for i in 0..<count {
                if let gPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                    let transform = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                    composite.addPath(gPath, transform: transform)
                }
            }
        }
        return composite
    }
}
