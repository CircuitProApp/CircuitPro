import AppKit
import Observation

/// A scene graph node that extends `TextNode` to add visual adornments for its anchor.
///
/// This node draws a crosshair at the text's original definition position and a dashed
/// line connecting that anchor to the text's current position. It acts as the bridge
/// between the resolved `CircuitText` data model and the `TextModel` used for rendering.
@Observable
final class AnchoredTextNode: TextNode {

    // MARK: - Anchor and Data Provenance

    /// The original, un-overridden position from the definition.
    let definitionPosition: CGPoint

    /// A direct, unowned reference to the symbol instance that owns this text.
    /// This provides the link needed to persist changes back to the main data model.
    unowned let ownerInstance: SymbolInstance

    /// A link back to the data model's origin (definition or instance).
    let source: CircuitText.Source
    
    private let contentSource: TextSource
    private let displayOptions: TextDisplayOptions

    // MARK: - Initialization

    init(
        resolvedText: CircuitText.Resolved,
        ownerInstance: SymbolInstance
    ) {
        self.ownerInstance = ownerInstance
        self.source = resolvedText.source
        self.definitionPosition = resolvedText.definitionPosition
        self.contentSource = resolvedText.contentSource
        self.displayOptions = resolvedText.displayOptions

        // ID Generation Logic
        let nodeID: UUID
        switch resolvedText.source {
        case .definition(let definitionID):
            // Definition-based texts need a unique, stable ID per symbol instance.
            // We generate one by combining the instance's ID and the text's definition ID.
            nodeID = Self.generateStableID(for: ownerInstance.id, with: definitionID)
        case .instance:
            // Instance-specific texts already have a unique ID.
            nodeID = resolvedText.id
        }

        let textModelForRenderer = TextModel(
            id: nodeID,
            text: resolvedText.text,
            position: resolvedText.relativePosition,
            anchor: resolvedText.anchor,
            font: resolvedText.font,
            color: resolvedText.color,
            alignment: resolvedText.alignment,
            cardinalRotation: resolvedText.cardinalRotation
        )
        
        super.init(textModel: textModelForRenderer)
    }

    // MARK: - Overridden Drawable Conformance

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        // 1. Get the drawing primitives for the text itself from the superclass.
        var primitives = super.makeDrawingPrimitives()

        // 2. Convert the definition's anchor point to our local coordinate space.
        let localAnchorPosition = self.convert(definitionPosition, from: parent)
        let adornmentColor = NSColor.systemGray.withAlphaComponent(0.8).cgColor

        // 3. Create and append the drawing primitive for the anchor crosshair.
        let crosshairPath = makeCrosshairPath(at: localAnchorPosition)
        primitives.append(.stroke(path: crosshairPath, color: adornmentColor, lineWidth: 0.5))

        // 4. Create and append the drawing primitive for the dashed connector line.
        if let connectorPath = makeConnectorPath(from: localAnchorPosition) {
             primitives.append(.stroke(path: connectorPath, color: adornmentColor, lineWidth: 0.5, lineDash: [2, 2]))
        }

        return primitives
    }
}


// MARK: - Committing Changes
extension AnchoredTextNode {
    /// Persists the node's current visual state back into the main data model (`SymbolInstance`).
    /// This is the critical step that saves changes like repositioning.
    func commitChanges() {
        let resolvedModel = self.toResolvedModel()
        self.ownerInstance.update(with: resolvedModel)
    }

    /// Converts the node's current state back into an immutable `CircuitText.Resolved` data model.
    func toResolvedModel() -> CircuitText.Resolved {
        return CircuitText.Resolved(
            source: self.source,
            contentSource: self.contentSource,
            text: textModel.text,
            displayOptions: self.displayOptions,
            relativePosition: textModel.position,
            definitionPosition: self.definitionPosition,
            font: textModel.font,
            color: textModel.color,
            anchor: textModel.anchor,
            alignment: textModel.alignment,
            cardinalRotation: textModel.cardinalRotation,
            isVisible: true
        )
    }
}


// MARK: - Private Path Generation Helpers
private extension AnchoredTextNode {
    /// Creates the CGPath for the crosshair symbol centered at a given point.
    func makeCrosshairPath(at center: CGPoint, size: CGFloat = 8.0) -> CGPath {
        let halfSize = size / 2
        let path = CGMutablePath()
        
        // Horizontal line
        path.move(to: CGPoint(x: center.x - halfSize, y: center.y))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
        
        // Vertical line
        path.move(to: CGPoint(x: center.x, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
        
        return path
    }
    
    /// Creates the CGPath for the dashed line connecting the anchor to the text's bounding box.
    func makeConnectorPath(from anchorPosition: CGPoint) -> CGPath? {
        // The bounding box from the superclass is already in our local coordinate space.
        let textBounds = super.boundingBox
        guard !textBounds.isNull else { return nil }
        
        // Determine the best point on the text's bounding box to connect to.
        let connectionPoint = determineConnectionPoint(on: textBounds, towards: anchorPosition)
        
        let path = CGMutablePath()
        path.move(to: anchorPosition)
        path.addLine(to: connectionPoint)
        
        return path
    }
    
    /// Calculates the optimal point on a bounding box to draw a connector line to.
    /// This logic prevents the connector from awkwardly crossing through the text.
    func determineConnectionPoint(on rect: CGRect, towards point: CGPoint) -> CGPoint {
        // If the text is positioned significantly above or below the anchor,
        // connect to the center of the top or bottom edge.
        if abs(point.y - rect.midY) > abs(point.x - rect.midX) {
             if point.y > rect.maxY { // Anchor is above the text
                 return CGPoint(x: rect.midX, y: rect.maxY)
             } else if point.y < rect.minY { // Anchor is below the text
                 return CGPoint(x: rect.midX, y: rect.minY)
             }
        }
        
        // Otherwise, connect to the center of the left or right edge.
        if point.x > rect.maxX { // Anchor is to the right of the text
            return CGPoint(x: rect.maxX, y: rect.midY)
        } else { // Anchor is to the left of the text
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

// MARK: - ID Generation
private extension AnchoredTextNode {
    /// Generates a stable, unique UUID for a text node by combining the parent symbol's instance ID
    /// with the text's own definition ID. This is crucial for ensuring that texts derived from the
    /// same definition have unique identifiers across different symbol instances.
    ///
    /// We achieve this by XORing the bytes of the two UUIDs.
    static func generateStableID(for ownerID: UUID, with definitionID: UUID) -> UUID {
        var ownerBytes = ownerID.uuid
        var definitionBytes = definitionID.uuid

        let resultTuple = (
            ownerBytes.0 ^ definitionBytes.0, ownerBytes.1 ^ definitionBytes.1,
            ownerBytes.2 ^ definitionBytes.2, ownerBytes.3 ^ definitionBytes.3,
            ownerBytes.4 ^ definitionBytes.4, ownerBytes.5 ^ definitionBytes.5,
            ownerBytes.6 ^ definitionBytes.6, ownerBytes.7 ^ definitionBytes.7,
            ownerBytes.8 ^ definitionBytes.8, ownerBytes.9 ^ definitionBytes.9,
            ownerBytes.10 ^ definitionBytes.10, ownerBytes.11 ^ definitionBytes.11,
            ownerBytes.12 ^ definitionBytes.12, ownerBytes.13 ^ definitionBytes.13,
            ownerBytes.14 ^ definitionBytes.14, ownerBytes.15 ^ definitionBytes.15
        )
        
        return UUID(uuid: resultTuple)
    }
}
