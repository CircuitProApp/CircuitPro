//
//  Pin+Geometry.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/24/25.
//

import AppKit
import CoreText

extension Pin {

    // MARK: - Core Geometric Properties

    var length: CGFloat {
        switch lengthType {
        case .short: return 20
        case .long:  return 30
        }
    }

    var endpointRadius: CGFloat { 4.0 }

    // --- FIX 1: Calculate leg start relative to a (0,0) origin ---
    /// The local-space start of the pin’s "leg".
    var localLegStart: CGPoint {
        let dir = cardinalRotation.direction
        return CGPoint(x: dir.x * length, y: dir.y * length)
    }

    // MARK: - Composite Path Calculation
    
    // This method now correctly generates all paths in local space.
    func calculateCompositePath() -> CGPath {
        let outline = CGMutablePath()
        let textFattenAmount: CGFloat = 1.0

        // 1. Add local line and circle paths.
        let legPath = CGMutablePath()
        legPath.move(to: localLegStart) // Use local start
        legPath.addLine(to: .zero)      // End at the local origin (0,0)
        outline.addPath(legPath)
        
        let endpointRect = CGRect(x: -endpointRadius, y: -endpointRadius, width: endpointRadius * 2, height: endpointRadius * 2)
        outline.addPath(CGPath(ellipseIn: endpointRect, transform: nil)) // Centered on local origin

        // 2. Add pin number. The layout function is now local-space aware.
        if showNumber {
            var (path, transform) = numberLayout()
            if let transformedPath = path.copy(using: &transform) {
                let fattedText = transformedPath.copy(strokingWithWidth: textFattenAmount, lineCap: .round, lineJoin: .round, miterLimit: 1)
                outline.addPath(fattedText)
            }
        }
        
        // 3. Add pin label. The layout function is now local-space aware.
        if showLabel && !name.isEmpty {
            var (path, transform) = labelLayout()
            if let transformedPath = path.copy(using: &transform) {
                let fattedText = transformedPath.copy(strokingWithWidth: textFattenAmount, lineCap: .round, lineJoin: .round, miterLimit: 1)
                outline.addPath(fattedText)
            }
        }
        
        return outline
    }

    // MARK: - Text Layout Calculations (Now in Local Space)
    
    // --- FIX 2: Update text layout to use local coordinates ---
    func labelLayout() -> (path: CGPath, transform: CGAffineTransform) {
        let font = NSFont.systemFont(ofSize: 10)
        let pad: CGFloat = 4

        let textPath = TextUtilities.path(for: name, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        
        var transform: CGAffineTransform

        // `localLegStart` replaces the old absolute `legStart`.
        switch cardinalRotation {
        case .west:
            let anchor = CGPoint(x: trueBounds.maxX, y: trueBounds.midY)
            let target = CGPoint(x: localLegStart.x - pad, y: localLegStart.y)
            transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)

        case .east:
            let anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
            let target = CGPoint(x: localLegStart.x + pad, y: localLegStart.y)
            transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)
        
        case .north:
            let angle = CGFloat.pi / 2
            let rotation = CGAffineTransform(rotationAngle: angle)
            let anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
            let target = CGPoint(x: localLegStart.x, y: localLegStart.y + pad)
            let rotatedAnchor = anchor.applying(rotation)
            transform = rotation.concatenating(CGAffineTransform(translationX: target.x - rotatedAnchor.x, y: target.y - rotatedAnchor.y))
        
        case .south:
            let angle = CGFloat.pi / 2
            let rotation = CGAffineTransform(rotationAngle: angle)
            let anchor = CGPoint(x: trueBounds.maxX, y: trueBounds.midY)
            let target = CGPoint(x: localLegStart.x, y: localLegStart.y - pad)
            let rotatedAnchor = anchor.applying(rotation)
            transform = rotation.concatenating(CGAffineTransform(translationX: target.x - rotatedAnchor.x, y: target.y - rotatedAnchor.y))
        default: // east
            let anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
            let target = CGPoint(x: localLegStart.x + pad, y: localLegStart.y)
            transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)
        }
        
        return (textPath, transform)
    }

    func numberLayout() -> (path: CGPath, transform: CGAffineTransform) {
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let pad: CGFloat = 3
        let text = "\(number)"
        
        let textPath = TextUtilities.path(for: text, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        // `mid` is now calculated in local space: between (0,0) and localLegStart.
        let mid = CGPoint(x: localLegStart.x / 2, y: localLegStart.y / 2)
        
        let targetPos: CGPoint
        switch cardinalRotation {
        case .north:
            targetPos = CGPoint(x: mid.x + pad + trueBounds.width, y: mid.y - trueBounds.height / 2)
        case .south:
            targetPos = CGPoint(x: mid.x + pad, y: mid.y - trueBounds.height / 2)
        default: // Horizontal pins
            targetPos = CGPoint(x: mid.x - trueBounds.width / 2, y: mid.y + pad)
        }
        
        let transform = CGAffineTransform(translationX: targetPos.x - trueBounds.minX, y: targetPos.y - trueBounds.minY)
        return (textPath, transform)
    }
}
