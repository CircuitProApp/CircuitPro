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
    
    /// A unique ID for this specific canvas element instance, used for SwiftUI diffing.
    let id: UUID
    
    /// The underlying `TextElement` that handles all drawing, styling, and basic transformation.
    /// Its `position` is in absolute world coordinates.
    var textElement: TextElement

    /// The absolute world position of the parent object's anchor point.
    var anchorPosition: CGPoint
    
    /// The unique ID of the CanvasElement that owns this text's anchor.
    let anchorOwnerID: UUID
    
    // --- Data Provenance ---
    // This replaces `sourceDataID` and `isFromDefinition` with a single, clearer source.
    /// The data origin, used to reconstruct the `ResolvedText` object for saving changes.
    let origin: TextOrigin

    /// Initializes a canvas-ready element from a resolved data model.
    ///
    /// - Parameters:
    ///   - resolvedText: The fully resolved text data.
    ///   - parentID: The ID of the parent element (e.g., `SymbolElement`).
    ///   - parentTransform: The affine transform of the parent, used to calculate absolute world coordinates.
    init(resolvedText: ResolvedText, parentID: UUID, parentTransform: CGAffineTransform) {
        self.id = resolvedText.id
        self.anchorOwnerID = parentID
        self.origin = resolvedText.origin

        // 1. Calculate the absolute world positions from the parent's transform
        // and the text's relative positions.
        self.anchorPosition = resolvedText.anchorRelativePosition.applying(parentTransform)
        let absoluteTextPosition = resolvedText.relativePosition.applying(parentTransform)
        
        // 2. Create the underlying drawable TextElement.
        self.textElement = TextElement(
            id: UUID(), // Transient ID for the sub-element
            text: resolvedText.text,
            position: absoluteTextPosition,
            rotation: parentTransform.rotationAngle, // Text rotation should match its parent
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
        
        // 1. We only care about hits on the contained text element.
        // The anchor crosshair is purely visual decoration for now.
        guard let textHitResult = textElement.hitTest(point, tolerance: tolerance) else {
            // The text was not hit, so the entire element is considered missed.
            return nil
        }
        
        // 2. The text element was hit. We now establish this AnchoredTextElement
        // as the selectable owner. The ownership path from the child TextElement
        // is discarded, and a new path is started here.
        let newOwnerPath = [self.id]
        
        // 3. Return a new target that correctly identifies this element as the owner.
        // The `partID` and `kind` are passed through from the child, but the
        // `ownerPath` now makes this AnchoredTextElement the immediate owner.
        return CanvasHitTarget(
            partID: textHitResult.partID,
            ownerPath: newOwnerPath,
            kind: textHitResult.kind,  // This will be `.text` from the TextElement
            position: point
        )
    }
}
