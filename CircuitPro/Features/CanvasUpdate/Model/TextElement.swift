//
//  TextElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelize on 7/24/25.
//

import SwiftUI

struct TextElement: Identifiable {
    let id: UUID
    var text: String
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .east
    var font: NSFont = .systemFont(ofSize: 12)
    var color: CGColor = NSColor.black.cgColor
    var alignment: NSTextAlignment = .left
    var isEditable: Bool = false
}

// MARK: - Equatable, Hashable
extension TextElement: Equatable, Hashable {
    static func == (lhs: TextElement, rhs: TextElement) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.position == rhs.position &&
        lhs.cardinalRotation == rhs.cardinalRotation &&
        lhs.font == rhs.font &&
        lhs.color == rhs.color &&
        lhs.isEditable == rhs.isEditable
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Transformable
extension TextElement: Transformable {
    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closestWithDiagonals(to: newValue) }
    }
}

// MARK: - Bounded
extension TextElement: Bounded {
    var boundingBox: CGRect {
        let path = TextUtilities.path(for: text, font: font)
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
        return path.boundingBoxOfPath.applying(transform)
    }
}

// MARK: - Drawable
extension TextElement: Drawable {
    func makeBodyParameters() -> [DrawingParameters] {
        let path = TextUtilities.path(for: text, font: font)
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        guard let transformedPath = path.copy(using: &transform) else {
            return []
        }

        return [
            DrawingParameters(
                path: transformedPath,
                lineWidth: 0,
                fillColor: color,
                strokeColor: nil
            )
        ]
    }

    func makeHaloPath() -> CGPath? {
        // 1. Get the raw, un-transformed path for the text glyphs.
        let rawPath = TextUtilities.path(for: text, font: font)

        // 2. Create a new path by "stroking" the raw path. This creates an outline.
        let strokedPath = rawPath.copy(
            strokingWithWidth: 1.0, // A chunky outline for the halo
            lineCap: .round,       // Use round caps and joins for a softer look
            lineJoin: .round,
            miterLimit: 1.0
        )

        // 3. Apply the element's position and rotation to the new halo path.
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        return strokedPath.copy(using: &transform)
    }
}

// MARK: - Hittable
extension TextElement: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // 1. The hit detection logic is sound. We check if the point is within
        //    the element's bounding box, expanded by the tolerance value.
        let isHit = boundingBox.insetBy(dx: -tolerance, dy: -tolerance).contains(point)

        // 2. If the check fails, then the element was not hit.
        guard isHit else { return nil }
        
        // 3. If a hit occurred, we create the standard CanvasHitTarget to represent it.
        return CanvasHitTarget(
            // The part being hit is the TextElement itself.
            partID: self.id,
            
            // As a non-container element, its ownership path just contains its own ID.
            // If this TextElement is ever placed inside a group, the group's hitTest
            // will prepend its own ID to this path.
            ownerPath: [self.id],
            
            // For a general-purpose element like this, `.body` is the most
            // appropriate kind to describe the hit area.
            kind: .text,
            
            // We store the precise location of the hit.
            position: point
        )
    }
}
