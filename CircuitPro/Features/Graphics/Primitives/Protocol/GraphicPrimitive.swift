//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

protocol GraphicPrimitive: CanvasElement & HandleEditable & Codable {

    var id: UUID { get }
    var color: SDColor { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool { get set }

    func makePath() -> CGPath
}

// MARK: - Drawable Conformance
extension GraphicPrimitive {
    
    func makeBodyParameters() -> [DrawingParameters] {
        let params = DrawingParameters(
            path: makePath(),
            lineWidth: filled ? 0.0 : strokeWidth, // No stroke if filled
            fillColor: filled ? color.cgColor : nil,
            strokeColor: filled ? nil : color.cgColor,
            lineCap: .round,
            lineJoin: .miter
        )
        return [params]
    }

    /// Provides the path for the default halo implementation in the `Drawable` protocol.
    func makeHaloPath() -> CGPath? {
        return makePath()
    }
}

extension GraphicPrimitive {
    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
        guard selectedIDs.contains(self.id) else { return nil }

        guard let path = makeHaloPath(), !path.isEmpty else { return nil }

        let haloColor = self.color.nsColor.withAlphaComponent(0.3).cgColor

        return DrawingParameters(
            path: path,
            lineWidth: 4.0,
            fillColor: nil,
            strokeColor: haloColor
        )
    }
}

// MARK: - Other Shared Implementations
extension GraphicPrimitive {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        let path = makePath()
        let wasHit: Bool
        
        // --- LOGGING ---
        let shortID = self.id.uuidString.prefix(4)
        print("[GraphicPrimitive \(shortID)] Testing geometry. Received point (should be 0,0-centric): \(point)")
        
        if filled {
            wasHit = path.contains(point)
            print("[GraphicPrimitive \(shortID)]  -> Testing fill. Path contains point? \(wasHit)")
        } else {
            let stroke = path.copy(
                strokingWithWidth: strokeWidth + tolerance,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            wasHit = stroke.contains(point)
            print("[GraphicPrimitive \(shortID)]  -> Testing stroke. Stroked path contains point? \(wasHit)")
        }
        
        guard wasHit else { return nil }
        
        print("[GraphicPrimitive \(shortID)]  -> ✅ GEOMETRY HIT CONFIRMED.")
        
        return CanvasHitTarget(
            partID: self.id,
            ownerPath: [self.id],
            kind: .primitive,
            position: point
        )
    }

    var boundingBox: CGRect {
        var box = makePath().boundingBoxOfPath

        if !filled {
            let inset = -strokeWidth / 2
            box = box.insetBy(dx: inset, dy: inset)
        }
        return box
    }
}
