//
//  CanvasHitTarget.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 17.07.25.
//

import Foundation
import CoreGraphics

/// Represents the specific part of a connection that was hit.
enum ConnectionPart {
    case vertex(id: UUID, connectionID: UUID, position: CGPoint, type: VertexType)
    case edge(id: UUID, connectionID: UUID, at: CGPoint, orientation: LineOrientation)
}

/// Represents the specific part of a canvas element that was hit.
enum CanvasElementPart {
    case body(id: UUID)
    case pin(id: UUID, parentSymbolID: UUID?, position: CGPoint)
    case pad(id: UUID, position: CGPoint)
}

/// A detailed result of a hit-test operation on the canvas.
enum CanvasHitTarget {
    /// A part of a standard canvas element was hit.
    case canvasElement(part: CanvasElementPart)

    /// A part of a connection net was hit.
    case connection(part: ConnectionPart)

    // Future cases can be added here, for example:
    // case handle(ownerID: UUID, type: HandleType)
}

extension CanvasHitTarget {
    /// The ID of the top-level element that should be selected.
    /// For example, if a pin inside a symbol is hit, this returns the symbol's ID.
    var selectableID: UUID {
        switch self {
        case .canvasElement(let part):
            switch part {
            case .body(let id):
                return id
            case .pin(let pinID, let parentSymbolID, _):
                return parentSymbolID ?? pinID
            case .pad(let id, _):
                return id
            }
        case .connection(let part):
            switch part {
            case .vertex(_, let connectionID, _, _):
                return connectionID
            case .edge(let connectionID, _, _, _):
                return connectionID
            }
        }
    }
}
