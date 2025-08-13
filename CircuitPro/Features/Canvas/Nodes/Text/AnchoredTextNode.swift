import AppKit
import Observation

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

        super.init(textModel: textModel)
    }

    // MARK: - Overridden Drawable Conformance

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        // 1. Get the drawing primitives for the text itself from the superclass.
        var primitives = super.makeDrawingPrimitives()

        // 2. Convert the anchor point from the parent's space to our local space.
        let localAnchorPosition: CGPoint
        if let parent = self.parent {
            localAnchorPosition = self.convert(anchorPosition, from: parent)
        } else {
            localAnchorPosition = anchorPosition
        }

        let adornmentColor = NSColor.systemGray.withAlphaComponent(0.8).cgColor

        // 3. Create the drawing primitive for the anchor crosshair.
        let crossSize: CGFloat = 8.0
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: localAnchorPosition.x - crossSize / 2, y: localAnchorPosition.y))
        crossPath.addLine(to: CGPoint(x: localAnchorPosition.x + crossSize / 2, y: localAnchorPosition.y))
        crossPath.move(to: CGPoint(x: localAnchorPosition.x, y: localAnchorPosition.y - crossSize / 2))
        crossPath.addLine(to: CGPoint(x: localAnchorPosition.x, y: localAnchorPosition.y + crossSize / 2))

        primitives.append(.stroke(path: crossPath, color: adornmentColor, lineWidth: 0.5))

        // 4. Create the drawing primitive for the connector line.
        let textBounds = super.boundingBox
        if !textBounds.isNull && !textBounds.isEmpty {
            let connectionPoint: CGPoint
            if textBounds.midY > localAnchorPosition.y {
                // Text is above the anchor, connect to the bottom-middle of the text.
                connectionPoint = CGPoint(x: textBounds.midX, y: textBounds.minY)
            } else {
                // Text is below or level with the anchor, connect to the top-middle of the text.
                connectionPoint = CGPoint(x: textBounds.midX, y: textBounds.maxY)
            }

            let connectorPath = CGMutablePath()
            connectorPath.move(to: localAnchorPosition)
            connectorPath.addLine(to: connectionPoint)

            primitives.append(.stroke(path: connectorPath, color: adornmentColor, lineWidth: 0.5, lineDash: [2, 2]))
        }

        return primitives
    }
}


// MARK: - Committing Changes

extension AnchoredTextNode {
    /// Converts the node's current state back into a `ResolvedText` data model.
    func toResolvedText() -> ResolvedText {
        // The node's `position` is already relative to its parent (the SymbolNode),
        // and its `anchorPosition` is also stored relative to the parent.
        // The implementation is now simple and correct.
        return ResolvedText(
            origin: self.origin,
            text: self.textModel.text,
            font: self.textModel.font,
            color: self.textModel.color,
            alignment: self.textModel.alignment,
            anchor: self.textModel.anchor,
            relativePosition: self.position,
            anchorRelativePosition: self.anchorPosition,
            cardinalRotation: self.textModel.cardinalRotation
        )
    }
}
