//
//  CanvasHitTarget.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 17.07.25.
//

import Foundation
import CoreGraphics

/// A unified, detailed result of a hit-test operation on the canvas.
/// This structure provides the full hierarchical path to the hit component.
struct CanvasHitTarget: Equatable, Hashable {

    /// Defines the specific kind of component that was hit.
    enum Kind: Equatable, Hashable {
        // Canvas Elements
        case primitive      // A geometric primitive (line, rect, etc.).
        case pin            // A connection point on a symbol.
        case pad            // A surface-mount pad on a footprint.
        case text

        // Schematic Connections
        case vertex(type: VertexType)
        case edge(orientation: LineOrientation)
    }

    // 1. The unique ID of the specific part that was directly hit.
    let partID: UUID

    // 2. An array of UUIDs representing the full ownership hierarchy,
    //    from the top-level element down to the immediate parent.
    //    For a top-level element, this will contain its own ID.
    let ownerPath: [UUID]

    // 3. The specific kind of the component that was hit.
    let kind: Kind

    // 4. The precise location of the hit in world coordinates.
    let position: CGPoint
}


// MARK: - Helpers & Debugging
extension CanvasHitTarget {

    /// The ID of the top-level element that should be selected by default.
    var selectableID: UUID? {
        // The top-level owner is the first element in the path.
        return ownerPath.first
    }

    /// The ID of the immediate parent of the hit part.
    var immediateOwnerID: UUID? {
        return ownerPath.last
    }

    /// A convenience property to check if the hit target was a component pin.
    var isPin: Bool {
        if case .pin = kind {
            return true
        }
        return false
    }
    
    /// A debug helper to easily identify what was hit and its full ownership path.
    var debugDescription: String {
        let kindString: String
        switch kind {
        case .primitive: kindString = "Primitive"
        case .pin: kindString = "Pin"
        case .pad: kindString = "Pad"
        case .text: kindString = "Text"
        case .vertex(let type): kindString = "Vertex(\(type))"
        case .edge: kindString = "Edge"
        }

        let pathString = ownerPath
            .map { "...\($0.uuidString.suffix(4))" }
            .joined(separator: " -> ")
        
        return "\(kindString)(part: ...\(partID.uuidString.suffix(4)), path: [\(pathString)])"
    }
}
