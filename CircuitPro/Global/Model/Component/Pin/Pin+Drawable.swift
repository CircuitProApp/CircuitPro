//
//  Pin+Drawable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

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
    
    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
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
               if let transformedPath = path.copy(using: &transform) {
                   let fattedText = transformedPath.copy(strokingWithWidth: textFattenAmount, lineCap: .round, lineJoin: .round, miterLimit: 1)
                   outline.addPath(fattedText)
               }
           }
           
           guard !outline.isEmpty else { return nil }
           
           // 4. Return parameters to STROKE the final unified outline path.
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

        // Use the centralized TextUtilities to create the path.
        let textPath = TextUtilities.path(for: name, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        
        var transform: CGAffineTransform

        switch cardinalRotation {
        case .west: // Pin points left
            let anchor = CGPoint(x: trueBounds.maxX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x - pad, y: legStart.y)
            transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)

        case .east: // Pin points right
            let anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x + pad, y: legStart.y)
            transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)
        
        case .north: // Pin points up
            let angle = CGFloat.pi / 2
            let rotation = CGAffineTransform(rotationAngle: angle)
            let anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x, y: legStart.y + pad)
            let rotatedAnchor = anchor.applying(rotation)
            transform = rotation.concatenating(CGAffineTransform(translationX: target.x - rotatedAnchor.x, y: target.y - rotatedAnchor.y))
        
        case .south: // Pin points down
            let angle = CGFloat.pi / 2
            let rotation = CGAffineTransform(rotationAngle: angle)
            let anchor = CGPoint(x: trueBounds.maxX, y: trueBounds.midY)
            let target = CGPoint(x: legStart.x, y: legStart.y - pad)
            let rotatedAnchor = anchor.applying(rotation)
            transform = rotation.concatenating(CGAffineTransform(translationX: target.x - rotatedAnchor.x, y: target.y - rotatedAnchor.y))
        }
        
        return (textPath, transform)
    }

    func numberLayout() -> (path: CGPath, transform: CGAffineTransform) {
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let pad: CGFloat = 3
        let text = "\(number)"
        
        // Use the centralized TextUtilities to create the path.
        let textPath = TextUtilities.path(for: text, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        let mid = CGPoint(x: (position.x + legStart.x) / 2, y: (position.y + legStart.y) / 2)
        
        let targetPos: CGPoint
        switch cardinalRotation {
        case .east, .west: // Horizontal pins
            targetPos = CGPoint(x: mid.x - trueBounds.width / 2, y: mid.y + pad)
        case .north: // Pin points up
            targetPos = CGPoint(x: mid.x + pad + trueBounds.width, y: mid.y - trueBounds.height / 2)
        case .south: // Pin points down
            targetPos = CGPoint(x: mid.x + pad, y: mid.y - trueBounds.height / 2)
        }
        
        let transform = CGAffineTransform(translationX: targetPos.x - trueBounds.minX, y: targetPos.y - trueBounds.minY)
        return (textPath, transform)
    }
}
