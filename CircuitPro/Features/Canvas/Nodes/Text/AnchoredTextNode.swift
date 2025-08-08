//
//  AnchoredTextNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//


import AppKit

/// A scene graph node that represents a text element visually anchored to a parent object.
///
/// This node extends `TextNode`, inheriting all its text-rendering capabilities, and adds
/// visual adornments: a crosshair at the anchor point and a dashed line connecting
/// the anchor to the text. All drawing operations are performed in the node's local coordinate space.
@Observable
final class AnchoredTextNode: TextNode {

    // MARK: - Anchor Properties

    /// The position of the anchor in the parent's coordinate space.
    var anchorPosition: CGPoint

    /// The ID of the node that owns this anchor (e.g., a SymbolNode).
    let anchorOwnerID: UUID

    /// A link back to the original data model for committing changes.
    let origin: TextOrigin

    // MARK: - Initialization

    init(
        textModel: TextModel,
        anchorPosition: CGPoint,
        anchorOwnerID: UUID,
        origin: TextOrigin
    ) {
        self.anchorPosition = anchorPosition
        self.anchorOwnerID = anchorOwnerID
        self.origin = origin

        // Initialize the parent TextNode with the core text model.
        super.init(textModel: textModel)
    }

    // MARK: - Overridden Drawable Conformance

    override func makeBodyParameters() -> [DrawingParameters] {
        var params = super.makeBodyParameters()

        // Convert anchor to our local space
        let localAnchorPosition: CGPoint
        if let parent = self.parent {
            localAnchorPosition = self.convert(anchorPosition, from: parent)
        } else {
            localAnchorPosition = anchorPosition
        }

        // Anchor crosshair
        let crossSize: CGFloat = 8.0
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: localAnchorPosition.x - crossSize / 2, y: localAnchorPosition.y))
        crossPath.addLine(to: CGPoint(x: localAnchorPosition.x + crossSize / 2, y: localAnchorPosition.y))
        crossPath.move(to: CGPoint(x: localAnchorPosition.x, y: localAnchorPosition.y - crossSize / 2))
        crossPath.addLine(to: CGPoint(x: localAnchorPosition.x, y: localAnchorPosition.y + crossSize / 2))

        params.append(DrawingParameters(
            path: crossPath,
            lineWidth: 0.5,
            strokeColor: NSColor.systemGray.withAlphaComponent(0.8).cgColor
        ))

        // Very simple connector: to mid-x, min-y of bounding box
        let textBounds = super.boundingBox
        if !textBounds.isNull && !textBounds.isEmpty {
            let connectionPoint = CGPoint(
                x: textBounds.midX,
                y: textBounds.minY
            )

            let connectorPath = CGMutablePath()
            connectorPath.move(to: localAnchorPosition)
            connectorPath.addLine(to: connectionPoint)

            params.append(DrawingParameters(
                path: connectorPath,
                lineWidth: 0.5,
                strokeColor: NSColor.systemGray.withAlphaComponent(0.8).cgColor
            ))
        }

        return params
    }
    
    /// Finds the best connection point on a rectangle's edge for a line from an external point.
    private func findConnectionPoint(from point: CGPoint, to rect: CGRect) -> CGPoint {
        guard !rect.isNull && !rect.isEmpty && rect.width.isFinite && rect.height.isFinite else {
            return point // or some safe fallback
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = center.x - point.x
        let dy = center.y - point.y

        // Avoid any division by zero
        if dx == 0 && dy == 0 {
            return center
        }

        // Safe intersection math
        var x_intersect = point.x
        var y_intersect = point.y
        
        if dy != 0 {
            x_intersect += (dx / max(abs(dy), .ulpOfOne)) * (rect.height / 2.0)
        }
        if dx != 0 {
            y_intersect += (dy / max(abs(dx), .ulpOfOne)) * (rect.width / 2.0)
        }

        if rect.minX...rect.maxX ~= x_intersect {
            return CGPoint(x: x_intersect, y: dy > 0 ? rect.minY : rect.maxY)
        } else {
            return CGPoint(x: dx > 0 ? rect.minX : rect.maxX, y: y_intersect)
        }
    }
}


// MARK: - Committing Changes

extension AnchoredTextNode {
    /// Converts the node's current state back into a `ResolvedText` data model.
    /// This logic would typically be called by a higher-level controller before saving.
    func toResolvedText() -> ResolvedText {
        // The node's position and rotation are already relative to its parent.
        let relativePosition = self.position
        
        // Convert the absolute world anchor position back to a relative one.
        // It's simpler to just store the relative anchor and update it if the node moves.
        // For now, assuming anchorPosition is kept relative to the parent.
        let inverseParentTransform = self.parent?.worldTransform.inverted() ?? .identity
        let worldAnchorPosition = self.anchorPosition.applying(self.parent?.worldTransform ?? .identity)
        let relativeAnchorPosition = worldAnchorPosition.applying(inverseParentTransform)

        return ResolvedText(
            origin: self.origin,
            text: self.textModel.text,
            font: self.textModel.font,
            color: self.textModel.color,
            alignment: self.textModel.alignment,
            relativePosition: relativePosition,
            anchorRelativePosition: relativeAnchorPosition,
            cardinalRotation: self.textModel.cardinalRotation
        )
    }
}
