//
//  AnchoredTextElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import SwiftUI

/// Represents a text element on the canvas that is visually and logically
/// anchored to a parent element. It is a pure "view model" for the canvas,
/// initialized from a `ResolvedText` object.
struct AnchoredTextElement: Identifiable {
    
    let id: UUID
    
    var textElement: TextElement
    var anchorPosition: CGPoint
    let anchorOwnerID: UUID
    
    // --- Data Provenance ---
    // The link back to the data model for saving changes.
    let origin: TextOrigin

    init(resolvedText: ResolvedText, parentID: UUID, parentTransform: CGAffineTransform) {
        // Generate a new, unique ID for this instance on the canvas.
        self.id = UUID()
        
        self.anchorOwnerID = parentID
        self.origin = resolvedText.origin

        let absoluteTextPosition = resolvedText.relativePosition.applying(parentTransform)
        self.anchorPosition = resolvedText.anchorRelativePosition.applying(parentTransform)
        
        self.textElement = TextElement(
            id: resolvedText.id, // The textElement can keep the source ID for its own needs.
            text: resolvedText.text,
            position: absoluteTextPosition,
            rotation: parentTransform.rotationAngle,
            font: resolvedText.font,
            color: resolvedText.color,
            alignment: resolvedText.alignment
        )
    }
}

// MARK: - Committing Changes
extension AnchoredTextElement {
    /// Converts the canvas element's state back into a `ResolvedText` data model,
    /// ready to be passed to the "committer" logic on the `SymbolInstance`.
    func toResolvedText(parentTransform: CGAffineTransform) -> ResolvedText {
        // Use the inverse transform to convert world coordinates back to the parent's local space.
        let inverseTransform = parentTransform.inverted()
        let newRelativePosition = self.textElement.position.applying(inverseTransform)
        
        return ResolvedText(
            origin: self.origin,
            text: self.textElement.text,
            font: self.textElement.font,
            color: self.textElement.color,
            alignment: self.textElement.alignment,
            relativePosition: newRelativePosition,
            anchorRelativePosition: self.anchorPosition.applying(inverseTransform)
        )
    }
}

// MARK: - Protocol Conformances (via Delegation)

// We delegate most protocol requirements to the composed `textElement`,
// as it already knows how to be drawn, sized, and hit-tested.

extension AnchoredTextElement: Equatable, Hashable {
    static func == (lhs: AnchoredTextElement, rhs: AnchoredTextElement) -> Bool {
        lhs.id == rhs.id &&
        lhs.textElement == rhs.textElement &&
        lhs.anchorPosition == rhs.anchorPosition
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension AnchoredTextElement: Transformable {
    var position: CGPoint {
        get { textElement.position }
        set { textElement.position = newValue }
    }

    var rotation: CGFloat {
        get { textElement.rotation }
        set { textElement.rotation = newValue }
    }
}

extension AnchoredTextElement: Bounded {
    var boundingBox: CGRect {
        textElement.boundingBox
    }
}

extension AnchoredTextElement: Drawable {
    func makeBodyParameters() -> [DrawingParameters] {
        // 1. Start with the drawing parameters for the text itself.
        var allParameters = textElement.makeBodyParameters()

        // 2. Define drawing parameters for the anchor cross mark.
        let crossSize: CGFloat = 8.0
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: anchorPosition.x - crossSize / 2, y: anchorPosition.y))
        crossPath.addLine(to: CGPoint(x: anchorPosition.x + crossSize / 2, y: anchorPosition.y))
        crossPath.move(to: CGPoint(x: anchorPosition.x, y: anchorPosition.y - crossSize / 2))
        crossPath.addLine(to: CGPoint(x: anchorPosition.x, y: anchorPosition.y + crossSize / 2))

        let crossParams = DrawingParameters(
            path: crossPath,
            lineWidth: 0.5,
            fillColor: nil,
            strokeColor: NSColor.systemGray.withAlphaComponent(0.8).cgColor
        )
        allParameters.append(crossParams)
        
        // 3. Define drawing parameters for the dashed connector line.
        let connectorPath = CGMutablePath()
        connectorPath.move(to: anchorPosition)
    
        // Calculate the center of the text's bounding box using public properties.
        let textBoundingBox = textElement.boundingBox
        let textBottomLeading = CGPoint(x: textBoundingBox.minX, y: textBoundingBox.minY)
        
        connectorPath.addLine(to: textBottomLeading)
        
        let connectorParams = DrawingParameters(
            path: connectorPath,
            lineWidth: 0.5,
            fillColor: nil,
            strokeColor: NSColor.systemGray.withAlphaComponent(0.8).cgColor,
            lineDashPattern: [2, 3] // A nice dashed pattern
        )
        allParameters.append(connectorParams)

        // 4. Return the combined list of all parameters.
        return allParameters
    }

    /// This element's halo is defined by its contained text element.
    func makeHaloPath() -> CGPath? {
        return textElement.makeHaloPath()
    }
}

private extension CGAffineTransform {
    var rotationAngle: CGFloat {
        return atan2(b, a)
    }
}

extension AnchoredTextElement: Hittable {
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        guard let textHitResult = textElement.hitTest(point, tolerance: tolerance) else {
            return nil
        }
        
        // THIS IS THE FIX: The ownerPath now starts with THIS element's unique canvas ID.
        let newOwnerPath = [self.id]
        
        return CanvasHitTarget(
            partID: textHitResult.partID,
            ownerPath: newOwnerPath,
            kind: textHitResult.kind,
            position: point
        )
    }
}
