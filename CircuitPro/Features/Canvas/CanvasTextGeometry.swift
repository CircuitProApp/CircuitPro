//
//  CanvasTextGeometry.swift
//  CircuitPro
//
//  Created by Codex on 12/31/25.
//

import AppKit
import CoreGraphics

struct CanvasTextGeometry {
    static func localPath(for text: String, font: NSFont, anchor: TextAnchor) -> CGPath {
        let untransformedPath = CKText.path(for: text, font: font)
        guard !untransformedPath.isEmpty else { return untransformedPath }

        let targetPoint = anchor.point(in: untransformedPath.boundingBoxOfPath)
        let offset = CGVector(dx: -targetPoint.x, dy: -targetPoint.y)
        var transform = CGAffineTransform(translationX: offset.dx, y: offset.dy)
        return untransformedPath.copy(using: &transform) ?? untransformedPath
    }

    static func worldPosition(relativePosition: CGPoint, ownerTransform: CGAffineTransform) -> CGPoint {
        relativePosition.applying(ownerTransform)
    }

    static func worldAnchorPosition(anchorPosition: CGPoint, ownerTransform: CGAffineTransform) -> CGPoint {
        anchorPosition.applying(ownerTransform)
    }

    static func worldTransform(
        relativePosition: CGPoint,
        textRotation: CGFloat,
        ownerTransform: CGAffineTransform,
        ownerRotation: CGFloat
    ) -> CGAffineTransform {
        let worldPosition = relativePosition.applying(ownerTransform)
        let worldRotation = ownerRotation + textRotation
        return CGAffineTransform(translationX: worldPosition.x, y: worldPosition.y)
            .rotated(by: worldRotation)
    }

    static func worldPath(
        for text: String,
        font: NSFont,
        anchor: TextAnchor,
        relativePosition: CGPoint,
        anchorPosition: CGPoint,
        textRotation: CGFloat,
        ownerTransform: CGAffineTransform,
        ownerRotation: CGFloat
    ) -> CGPath {
        let local = localPath(for: text, font: font, anchor: anchor)
        guard !local.isEmpty else { return local }
        var transform = worldTransform(
            relativePosition: relativePosition,
            textRotation: textRotation,
            ownerTransform: ownerTransform,
            ownerRotation: ownerRotation
        )
        return local.copy(using: &transform) ?? local
    }
}
