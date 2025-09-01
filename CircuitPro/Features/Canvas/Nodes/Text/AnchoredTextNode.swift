import AppKit
import Observation

/// A scene graph node that extends `TextNode` to add visual adornments for its anchor.
///
/// This node acts as a specialized controller for component-owned text.
@Observable
final class AnchoredTextNode: TextNode {

    // MARK: - Data Provenance

    /// A direct, unowned reference to the symbol instance that owns this text.
    unowned let ownerInstance: SymbolInstance

    // MARK: - Computed Properties
    
    var anchorPosition: CGPoint {
        get { super.resolvedText.anchorPosition }
        set { super.resolvedText.anchorPosition = newValue }
    }
    
    var source: CircuitText.Source {
        super.resolvedText.source
    }
    
    // MARK: - Initialization

    init(
        resolvedText: CircuitText.Resolved,
        text: String, // Accepts the new display string.
        ownerInstance: SymbolInstance
    ) {
        self.ownerInstance = ownerInstance

        // ID Generation Logic: The node's ID must be stable across canvas rebuilds.
        let nodeID: UUID
        switch resolvedText.source {
        case .definition(let definition):
            nodeID = Self.generateStableID(for: ownerInstance.id, with: definition.id)
        case .instance:
            nodeID = resolvedText.id
        }
        
        // Pass both the model and the final string to the superclass initializer.
        super.init(id: nodeID, resolvedText: resolvedText, text: text)
    }

    // MARK: - Overridden Drawable Conformance

    override func makeDrawingPrimitives() -> [DrawingPrimitive] {
        var primitives = super.makeDrawingPrimitives()

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
    /// Persists the current state of the node's model back to the `SymbolInstance`.
    /// This is called automatically by the superclass when `resolvedText` is modified.
    func commitChanges() {
        // We simply apply the entire `resolvedText` model, which is the single source of truth.
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
        
        let connectionPoint = determineConnectionPoint(on: textBounds, towards: anchorPosition)
        
        let path = CGMutablePath()
        path.move(to: anchorPosition)
        path.addLine(to: connectionPoint)
        
        return path
    }
    
    func determineConnectionPoint(on rect: CGRect, towards point: CGPoint) -> CGPoint {
        if abs(point.y - rect.midY) > abs(point.x - rect.midX) {
             if point.y > rect.maxY { return CGPoint(x: rect.midX, y: rect.maxY) }
             else if point.y < rect.minY { return CGPoint(x: rect.midX, y: rect.minY) }
        }
        
        if point.x > rect.maxX { return CGPoint(x: rect.maxX, y: rect.midY) }
        else { return CGPoint(x: rect.minX, y: rect.midY) }
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
