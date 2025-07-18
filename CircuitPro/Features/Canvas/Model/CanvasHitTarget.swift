//
//  CanvasHitTarget.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 17.07.25.
//

import Foundation
import CoreGraphics

/// Represents the specific part of a connection from the `SchematicGraph` that was hit.
///
/// The `connectionID` has been removed. With a unified graph, individual
/// vertices and edges are the primary hittable objects, not a parent container.
enum ConnectionPart: Equatable, Hashable {
    /// A vertex (a connection point, junction, or endpoint) was hit.
    case vertex(id: UUID, position: CGPoint, type: VertexType)
    
    /// An edge (a wire segment) was hit.
    case edge(id: UUID, at: CGPoint, orientation: LineOrientation)
}

/// Represents the specific part of a standard canvas element (e.g., a symbol) that was hit.
/// This part of the enum remains unchanged.
enum CanvasElementPart: Equatable, Hashable {
    case body(id: UUID)
    case pin(id: UUID, parentSymbolID: UUID?, position: CGPoint)
    case pad(id: UUID, position: CGPoint)
}

/// A detailed result of a hit-test operation on the canvas.
enum CanvasHitTarget: Equatable, Hashable {
    /// A part of a standard canvas element was hit.
    case canvasElement(part: CanvasElementPart)

    /// A part of the schematic's connectivity graph was hit.
    case connection(part: ConnectionPart)
}


// MARK: - Helpers & Debugging
extension CanvasHitTarget {
    
    /// The ID of the specific primitive that should be added to the selection set.
    /// Returns `nil` for primitives that are hittable but not selectable, like vertices.
    var selectableID: UUID? {
        switch self {
        case .canvasElement(let part):
            switch part {
            case .body(let id):
                // Hitting the body of a symbol selects the symbol.
                return id
            case .pin(let pinID, let parentSymbolID, _):
                // Hitting a pin selects its parent symbol (if it has one).
                return parentSymbolID ?? pinID
            case .pad(let id, _):
                return id
            }
        case .connection(let part):
            switch part {
            case .vertex:
                // Vertices are not directly selectable.
                return nil
            case .edge(let id, _, _):
                // Edges are selectable.
                return id
            }
        }
    }
    
    /// A convenience property to check if the hit target was a component pin.
    func hitTargetIsPin() -> Bool {
        if case .canvasElement(part: .pin) = self {
            return true
        }
        return false
    }

    /// A debug helper to easily identify what was hit.
    var debugDescription: String {
        switch self {
        case .canvasElement(let part):
            switch part {
            case .body(let id): return "ElementBody(id: ...\(id.uuidString.suffix(4)))"
            case .pin(let id, _, _): return "Pin(id: ...\(id.uuidString.suffix(4)))"
            case .pad(let id, _): return "Pad(id: ...\(id.uuidString.suffix(4)))"
            }
        case .connection(let part):
            switch part {
            case .vertex(let id, _, let type): return "Vertex(\(type), id: ...\(id.uuidString.suffix(4)))"
            case .edge(let id, _, _): return "Edge(id: ...\(id.uuidString.suffix(4)))"
            }
        }
    }
}
