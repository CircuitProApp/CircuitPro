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
    var rotation: CGFloat = 0.0
    var font: NSFont = .systemFont(ofSize: 12)
    var color: CGColor = NSColor.black.cgColor
    var isEditable: Bool = false
}

// MARK: - Equatable, Hashable
extension TextElement: Equatable, Hashable {
    static func == (lhs: TextElement, rhs: TextElement) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.position == rhs.position &&
        lhs.rotation == rhs.rotation &&
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
    // Position and rotation are already implemented as stored properties.
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

    func makeHaloParameters() -> DrawingParameters? {
        let path = TextUtilities.path(for: text, font: font)
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        guard let transformedPath = path.copy(using: &transform) else {
            return nil
        }

        return DrawingParameters(
            path: transformedPath,
            lineWidth: 4.0,
            fillColor: nil,
            strokeColor: NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        )
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
