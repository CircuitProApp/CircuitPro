import AppKit
import Observation

/// A scene graph node that extends `TextNode` to add visual adornments for its anchor.
///
/// This node acts as a specialized controller for component-owned text.
@Observable
final class AnchoredTextNode: TextNode {

    // MARK: - Data Provenance

    /// A direct, unowned reference to the instance (Symbol or Footprint) that owns this text.
    // MODIFIED: Type changed from SymbolInstance to the generic TextOwningInstance protocol.
    unowned let ownerInstance: TextOwningInstance

    // MARK: - Computed Properties
    
    var anchorPosition: CGPoint {
        get { super.resolvedText.anchorPosition }
        set { super.resolvedText.anchorPosition = newValue }
    }
    
    var source: CircuitText.Source {
        super.resolvedText.source
    }
    
    // MARK: - Initialization

    // MODIFIED: ownerInstance parameter type changed to TextOwningInstance.
    init(
        resolvedText: CircuitText.Resolved,
        text: String, // Accepts the new display string.
        ownerInstance: TextOwningInstance
    ) {
        self.ownerInstance = ownerInstance

        // ID Generation Logic: The node's ID must be stable across canvas rebuilds.
        let nodeID: UUID
        switch resolvedText.source {
        case .definition(let definition):
            // The ownerInstance.id is used here, which is provided by the TextOwningInstance protocol.
            nodeID = Self.generateStableID(for: ownerInstance.id  as! UUID, with: definition.id)
        case .instance:
            nodeID = resolvedText.id
        }
        
        // Pass both the model and the final string to the superclass initializer.
        super.init(id: nodeID, resolvedText: resolvedText, text: text)
    }

    // MARK: - Overridden Drawable Conformance

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        var primitives = super.makeDrawingPrimitives()

        // The position here needs to be in the AnchoredTextNode's local coordinate space.
        // Assuming `anchorPosition` is already in its parent's (SymbolNode/FootprintNode) coordinate space,
        // we convert it to this node's local space for drawing the adornments.
        let localAnchorPosition = self.convert(anchorPosition, from: parent)
        let adornmentColor = NSColor.systemGray.withAlphaComponent(0.8).cgColor

        let crosshairPath = makeCrosshairPath(at: localAnchorPosition)
        primitives.append(.stroke(path: crosshairPath, color: adornmentColor, lineWidth: 0.5))

        if let connectorPath = makeConnectorPath(from: localAnchorPosition) {
             primitives.append(.stroke(path: connectorPath, color: adornmentColor, lineWidth: 0.5, lineDash: [2, 2]))
        }

        return primitives
    }
}

// MARK: - Committing Changes
extension AnchoredTextNode {
    /// Persists the current state of the node's model back to its `ownerInstance`.
    /// This is called automatically by the superclass when `resolvedText` is modified.
    func commitChanges() {
        // We simply apply the entire `resolvedText` model, which is the single source of truth.
        // This relies on the `ownerInstance` (SymbolInstance or FootprintInstance)
        // correctly implementing the `apply` method to update its internal resolved texts.
        self.ownerInstance.apply(self.resolvedText)
    }
}

// MARK: - Private Path Generation Helpers
private extension AnchoredTextNode {
    func makeCrosshairPath(at center: CGPoint, size: CGFloat = 8.0) -> CGPath {
        let halfSize = size / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x - halfSize, y: center.y))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
        return path
    }
    
    func makeConnectorPath(from anchorPosition: CGPoint) -> CGPath? {
        let textBounds = super.boundingBox
        guard !textBounds.isNull else { return nil }
        
        // Need to ensure `textBounds` is in the same coordinate space as `anchorPosition`
        // before determining the connection point. `super.boundingBox` is in local space.
        // If `anchorPosition` is in parent's space, it should be converted, or `textBounds` should be.
        // For simplicity, assuming `anchorPosition` is already in local space here if it's based on `super.resolvedText.anchorPosition`.
        // If `anchorPosition` is truly in the parent's coordinates, you might need:
        // let localTextBounds = self.convert(textBounds, to: parent) // Convert text bounds to parent's space for comparison.
        
        let connectionPoint = determineConnectionPoint(on: textBounds, towards: anchorPosition)
        
        let path = CGMutablePath()
        path.move(to: anchorPosition)
        path.addLine(to: connectionPoint)
        
        return path
    }
    
    func determineConnectionPoint(on rect: CGRect, towards point: CGPoint) -> CGPoint {
        // This logic determines which side of the text's bounding box the connector line should attach to.
        // It prioritizes vertical connection if the point is further vertically, otherwise horizontal.

        // Calculate deltas from rect center to point
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY

        // Use aspect ratio to determine if connection should be primarily horizontal or vertical
        // This prevents connections to corners when the point is mostly in one direction
        let absDx = abs(dx)
        let absDy = abs(dy)

        if absDx * rect.height > absDy * rect.width { // More horizontal alignment needed relative to text aspect ratio
            if dx > 0 { // Point is to the right
                return CGPoint(x: rect.maxX, y: rect.midY)
            } else { // Point is to the left
                return CGPoint(x: rect.minX, y: rect.midY)
            }
        } else { // More vertical alignment needed
            if dy > 0 { // Point is above
                return CGPoint(x: rect.midX, y: rect.maxY)
            } else { // Point is below
                return CGPoint(x: rect.midX, y: rect.minY)
            }
        }
    }
}

// MARK: - ID Generation
private extension AnchoredTextNode {
    static func generateStableID(for ownerID: UUID, with definitionID: UUID) -> UUID {
        var ownerBytes = ownerID.uuid
        var definitionBytes = definitionID.uuid
        var resultBytes = ownerBytes

        withUnsafeMutableBytes(of: &resultBytes) { resultPtr in
            withUnsafeBytes(of: &definitionBytes) { definitionPtr in
                for i in 0..<resultPtr.count {
                    resultPtr[i] ^= definitionPtr[i]
                }
            }
        }
        return UUID(uuid: resultBytes)
    }
}
