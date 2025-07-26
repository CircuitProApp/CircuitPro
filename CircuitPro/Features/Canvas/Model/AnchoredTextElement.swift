//
//  AnchoredTextElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import SwiftUI

/// Represents a text element on the canvas that is visually and logically
/// anchored to a parent element, like a symbol.
struct AnchoredTextElement: Identifiable {
    
    /// A unique ID for this specific canvas element instance.
    var id: UUID
    
    /// The underlying `TextElement` that handles all drawing, styling, and basic transformation.
    /// Its `position` is in absolute world coordinates.
    var textElement: TextElement

    // MARK: - Anchor properties
    
    /// The absolute world position of the parent object's anchor point.
    /// This is used to draw a connector line when the text is being moved.
    var anchorPosition: CGPoint
    
    /// The unique ID of the CanvasElement that owns this text's anchor.
    /// This generic name allows it to be linked to a SymbolElement, a NetElement, etc.
    let anchorOwnerID: UUID
    
    // MARK: - Data-binding properties
    
    /// A stable ID that links this canvas element back to its source data model
    /// (either an `AnchoredTextDefinition` or an `InstanceAdHocText`).
    let sourceDataID: UUID
    
    /// A flag indicating whether this text originates from a library definition
    /// (`true`) or is an ad-hoc addition on the instance (`false`).
    /// This tells our saving logic which array to modify.
    let isFromDefinition: Bool
}

// MARK: - Protocol Conformances (via Delegation)

// We delegate most protocol requirements to the composed `textElement`,
// as it already knows how to be drawn, sized, and hit-tested.

extension AnchoredTextElement: Equatable, Hashable {
    // For equality, we check our own ID, the state of the text element,
    // and the anchor position, as a change in any of these requires a redraw.
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
        
        // --- THIS IS THE FIX ---
        // Calculate the center of the text's bounding box using public properties.
        let textBoundingBox = textElement.boundingBox
        let textCenter = CGPoint(x: textBoundingBox.midX, y: textBoundingBox.midY)
        // --- END OF FIX ---
        
        connectorPath.addLine(to: textCenter)
        
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

    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
        // 1. Check if this specific AnchoredTextElement is the selected item.
        guard selectedIDs.contains(self.id) else {
            // If we are not in the selection set, we should not draw a halo.
            return nil
        }
        
        // 2. We are selected, so delegate to our textElement to get the actual halo path.
        // We don't need to pass selectedIDs down further, as we've already made the decision.
        return textElement.makeHaloParameters()
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
        // as the selectable owner. We build a new ownership path by prepending
        // our own ID to the path we received from the textElement.
        let newOwnerPath = [self.id] + textHitResult.ownerPath
        
        // 3. Return a new target that correctly identifies the full hierarchy.
        // The `partID` and `kind` are passed through from the child, but the
        // `ownerPath` now reflects that this AnchoredTextElement is the owner.
        return CanvasHitTarget(
            partID: textHitResult.partID,
            ownerPath: newOwnerPath,
            kind: textHitResult.kind,  // This will be `.text` from the TextElement
            position: point
        )
    }
}
