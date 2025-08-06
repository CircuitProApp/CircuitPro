//
//  Pin+Geometry.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/24/25.
//
//  CORRECTED VERSION: Restores world-coordinate geometry calculations.
//

import AppKit
import CoreText

extension Pin {

    // MARK: - Core Geometric Properties (World-Space)

    var length: CGFloat {
        switch lengthType {
        case .short: return 20
        case .long:  return 30
        }
    }

    var endpointRadius: CGFloat { 4.0 }

    /// The calculated world-space start position of the pin's leg.
    /// This is the same logic as the original Pin+Drawable.
    var localLegStart: CGPoint {
        let dir = cardinalRotation.direction
        // Calculates start position relative to an endpoint at (0,0).
        return CGPoint(x: dir.x * length, y: dir.y * length)
    }

    // MARK: - Composite Path and Layout (World-Space)
    
    /// Creates a single path representing the pin's footprint in WORLD coordinates.
    func calculateCompositePath() -> CGPath {
        let outline = CGMutablePath()
        let textFattenAmount: CGFloat = 1.0 // A small width to fill in text for hit-testing.

        // 1. Add local line and circle paths.
        let legPath = CGMutablePath()
        legPath.move(to: localLegStart) // Use local start
        legPath.addLine(to: .zero)      // End at the local origin (0,0)
        outline.addPath(legPath)
        
        let endpointRect = CGRect(x: -endpointRadius, y: -endpointRadius, width: endpointRadius * 2, height: endpointRadius * 2)
        outline.addPath(CGPath(ellipseIn: endpointRect, transform: nil)) // Centered on local origin

        // 2. Add pin number. The layout function returns a local-space path.
        if showNumber {
            var (path, transform) = numberLayout()
            if let transformedPath = path.copy(using: &transform) {
                let fattedText = transformedPath.copy(strokingWithWidth: textFattenAmount, lineCap: .round, lineJoin: .round, miterLimit: 1)
                outline.addPath(fattedText)
            }
        }
        
        // 3. Add pin label. The layout function also returns a local-space path.
        if showLabel && !name.isEmpty {
            var (path, transform) = labelLayout()
            if let transformedPath = path.copy(using: &transform) {
                let fattedText = transformedPath.copy(strokingWithWidth: textFattenAmount, lineCap: .round, lineJoin: .round, miterLimit: 1)
                outline.addPath(fattedText)
            }
        }
        
        return outline
    }
    
    func makeAllBodyParameters() -> [DrawingParameters] {
        let pinColor = NSColor.systemBlue.cgColor
        var params: [DrawingParameters] = []
        let localOrigin = CGPoint.zero

        // 1. Draw Leg and Endpoint in local space.
        let legPath = CGMutablePath()
        legPath.move(to: localLegStart) // From local start
        legPath.addLine(to: localOrigin) // To local origin
        params.append(DrawingParameters(path: legPath, lineWidth: 1, strokeColor: pinColor))
        
        let endpointRect = CGRect(x: localOrigin.x - endpointRadius, y: localOrigin.y - endpointRadius, width: endpointRadius * 2, height: endpointRadius * 2)
        params.append(DrawingParameters(path: CGPath(ellipseIn: endpointRect, transform: nil), lineWidth: 1, strokeColor: pinColor))

        // 2 & 3. Draw text, also in local space.
        if showNumber {
            var (path, transform) = numberLayout()
            if let finalPath = path.copy(using: &transform) {
                params.append(DrawingParameters(path: finalPath, lineWidth: 0, fillColor: pinColor))
            }
        }
        
        if showLabel && !name.isEmpty {
            var (path, transform) = labelLayout()
            if let finalPath = path.copy(using: &transform) {
                params.append(DrawingParameters(path: finalPath, lineWidth: 0, fillColor: pinColor))
            }
        }
        return params
    }

    // --- Text layout functions updated to use LOCAL coordinates ---

    func labelLayout() -> (path: CGPath, transform: CGAffineTransform) {
        let font = NSFont.systemFont(ofSize: 10)
        let pad: CGFloat = 4
        let textPath = TextUtilities.path(for: name, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        let (target, anchor): (CGPoint, CGPoint)

        // All targets are now relative to localLegStart, not the pin's world position.
        switch cardinalRotation {
        case .west:
            target = CGPoint(x: localLegStart.x - pad, y: localLegStart.y)
            anchor = CGPoint(x: trueBounds.maxX, y: trueBounds.midY)
        case .east:
            target = CGPoint(x: localLegStart.x + pad, y: localLegStart.y)
            anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
        case .north:
            target = CGPoint(x: localLegStart.x, y: localLegStart.y + pad)
            anchor = CGPoint(x: trueBounds.midX, y: trueBounds.minY)
        case .south:
            target = CGPoint(x: localLegStart.x, y: localLegStart.y - pad)
            anchor = CGPoint(x: trueBounds.midX, y: trueBounds.maxY)
        default:
            target = CGPoint(x: localLegStart.x + pad, y: localLegStart.y)
            anchor = CGPoint(x: trueBounds.minX, y: trueBounds.midY)
        }
        
        let transform = CGAffineTransform(translationX: target.x - anchor.x, y: target.y - anchor.y)
        return (textPath, transform)
    }

    func numberLayout() -> (path: CGPath, transform: CGAffineTransform) {
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let pad: CGFloat = 5
        let text = "\(number)"
        let textPath = TextUtilities.path(for: text, font: font)
        let trueBounds = textPath.boundingBoxOfPath
        
        // Midpoint is calculated on the LOCAL leg.
        let mid = CGPoint(x: localLegStart.x / 2, y: localLegStart.y / 2)
        let targetPos: CGPoint

        switch cardinalRotation {
        case .north:
            targetPos = CGPoint(x: mid.x + pad, y: mid.y)
        case .south:
            targetPos = CGPoint(x: mid.x + pad, y: mid.y)
        default: // Horizontal
            targetPos = CGPoint(x: mid.x, y: mid.y + pad)
        }
        
        let finalTarget = CGPoint(x: targetPos.x - trueBounds.midX, y: targetPos.y - trueBounds.midY)
        let transform = CGAffineTransform(translationX: finalTarget.x - trueBounds.minX, y: finalTarget.y - trueBounds.minY)
        return (textPath, transform)
    }
}
