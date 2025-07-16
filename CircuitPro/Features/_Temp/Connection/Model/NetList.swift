//
//  NetList.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import Foundation
import SwiftUI

/// Manages the collection of all connection nets in a schematic.
///
/// This class acts as a centralized store for `ConnectionElement` objects,
/// separating them from the main canvas elements like symbols and pins. This
/// allows for specialized handling of complex connection logic, such as merging,
/// splitting, and rubber-banding.
@Observable
class NetList {
    /// The collection of all connection nets.
    var connections: [ConnectionElement] = []

    /// Initializes an empty netlist.
    init(connections: [ConnectionElement] = []) {
        self.connections = connections
    }

    // MARK: - Modification

    /// Adds a new connection to the netlist.
    /// - Parameter connection: The `ConnectionElement` to add.
    func addConnection(_ connection: ConnectionElement) {
        connections.append(connection)
    }

    /// Removes a connection from the netlist by its ID.
    /// - Parameter id: The `UUID` of the connection to remove.
    func removeConnection(id: UUID) {
        connections.removeAll { $0.id == id }
    }

    // MARK: - Hit Testing

    /// Finds the connection element that is hit by a given point.
    /// - Parameters:
    ///   - point: The point to test, in canvas coordinates.
    ///   - tolerance: The tolerance for the hit test.
    /// - Returns: The `ConnectionElement` that was hit, or `nil` if no connection was hit.
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> ConnectionElement? {
        for connection in connections {
            if connection.hitTest(point, tolerance: tolerance) {
                return connection
            }
        }
        return nil
    }
    
    // MARK: - Drawing
    
    /// Draws all the connections in the netlist.
    /// - Parameters:
    ///   - ctx: The graphics context to draw into.
    ///   - selection: A set of selected element IDs to control highlighting.
    ///   - allPinPositions: The positions of all pins on the canvas for drawing endpoints correctly.
    func draw(in ctx: CGContext, with selection: Set<UUID>, allPinPositions: [CGPoint]) {
        for connection in connections {
            connection.draw(in: ctx, with: selection, allPinPositions: allPinPositions)
        }
    }
}
