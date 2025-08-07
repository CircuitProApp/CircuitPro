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
//  the anchor to the text. All drawing operations are performed in the node's local coordinate space.
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
        // 1. Get the drawing parameters for the text itself by calling the superclass implementation.
        var params = super.makeBodyParameters()

        // 2. Calculate the anchor's position relative to this node's local origin.
        // The node's `position` is the text's position, and `anchorPosition` is the
        // anchor's position, both in the parent's coordinate space. The difference gives
        // us the vector from the text to the anchor.
        let localAnchorPosition = anchorPosition - self.position

        // 3. Draw the anchor crosshair at the local anchor position.
        let crossSize: CGFloat = 8.0
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: localAnchorPosition.x - crossSize / 2, y: localAnchorPosition.y))
        crossPath.addLine(to: CGPoint(x: localAnchorPosition.x + crossSize / 2, y: localAnchorPosition.y))
        crossPath.move(to: CGPoint(x: localAnchorPosition.x, y: localAnchorPosition.y - crossSize / 2))
        crossPath.addLine(to: CGPoint(x: localAnchorPosition.x, y: localAnchorPosition.y + crossSize / 2))

        let crossParams = DrawingParameters(
            path: crossPath,
            lineWidth: 0.5,
            strokeColor: NSColor.systemGray.withAlphaComponent(0.8).cgColor
        )
        params.append(crossParams)

        // 4. Draw the dashed connector line.
        let connectorPath = CGMutablePath()
        connectorPath.move(to: localAnchorPosition)
        
        // The connection point is on the text's bounding box, which is already in local coordinates.
        let textBoundingBox = super.boundingBox // Use the text's bounding box from the parent class
        let connectionPoint = findConnectionPoint(from: localAnchorPosition, to: textBoundingBox)
        connectorPath.addLine(to: connectionPoint)

        let connectorParams = DrawingParameters(
            path: connectorPath,
            lineWidth: 0.5,
            strokeColor: NSColor.systemGray.withAlphaComponent(0.8).cgColor,
            lineDashPattern: [2, 3]
        )
        params.append(connectorParams)

        return params
    }
    
    /// Finds the best connection point on a rectangle's edge for a line from an external point.
    private func findConnectionPoint(from point: CGPoint, to rect: CGRect) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = center.x - point.x
        let dy = center.y - point.y

        if rect.isEmpty || (dx == 0 && dy == 0) {
            return center
        }
        
        // This is a simplified but effective algorithm to find the intersection point on the edge.
        let x_intersect = point.x + (dy != 0 ? (dx / abs(dy)) * (rect.height / 2.0) : 0)
        let y_intersect = point.y + (dx != 0 ? (dy / abs(dx)) * (rect.width / 2.0) : 0)

        if x_intersect >= rect.minX && x_intersect <= rect.maxX {
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
