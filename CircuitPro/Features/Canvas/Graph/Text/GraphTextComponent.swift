//
//  GraphTextComponent.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import AppKit

/// A graph component representing a renderable, editable text element.
struct GraphTextComponent: GraphComponent {
    var resolvedText: CircuitText.Resolved
    var displayText: String

    /// The owning component instance ID (used to persist edits).
    var ownerID: UUID
    var target: TextTarget

    /// The owner's transform in world space.
    var ownerPosition: CGPoint
    var ownerRotation: CGFloat

    /// The text's derived transform in world space.
    var worldPosition: CGPoint
    var worldRotation: CGFloat
    var worldAnchorPosition: CGPoint

    var layerId: UUID?
    var showsAnchorGuides: Bool = false

    var isVisible: Bool { resolvedText.isVisible }
    var font: NSFont { resolvedText.font.nsFont }
    var color: CGColor { resolvedText.color.cgColor }
}

extension GraphTextComponent {
    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
            .rotated(by: ownerRotation)
    }

    var worldTransform: CGAffineTransform {
        CGAffineTransform(translationX: worldPosition.x, y: worldPosition.y)
            .rotated(by: worldRotation)
    }

    func localPath() -> CGPath {
        let untransformedPath = TextUtilities.path(for: displayText, font: font)
        guard !untransformedPath.isEmpty else { return untransformedPath }

        let targetPoint = resolvedText.anchor.point(in: untransformedPath.boundingBoxOfPath)
        let offset = CGVector(dx: -targetPoint.x, dy: -targetPoint.y)
        var transform = CGAffineTransform(translationX: offset.dx, y: offset.dy)
        return untransformedPath.copy(using: &transform) ?? untransformedPath
    }

    func worldPath() -> CGPath {
        let local = localPath()
        guard !local.isEmpty else { return local }
        var transform = worldTransform
        return local.copy(using: &transform) ?? local
    }
}
