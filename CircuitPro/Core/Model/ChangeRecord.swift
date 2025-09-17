//
//  ChangeRecord.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import Foundation

/// Represents the origin of a change within the application.
enum ChangeSource: Codable, Hashable {
    case schematic
    case layout
}

/// Defines the specific type of change that occurred.
/// This enum holds the necessary data to both describe and apply a change.
enum ChangeType: Codable, Hashable {
    /// Records a change to a component's reference designator index (e.g., from R5 to R6).
    case updateReferenceDesignator(componentID: UUID, newIndex: Int, oldIndex: Int)
    
    /// Records a change to a component's assigned footprint.
    case assignFootprint(componentID: UUID, newFootprintUUID: UUID?, newFootprintName: String?, oldFootprintName: String?)
    
    /// Records a change to a specific property of a component (e.g., updating resistance).
    case updateProperty(componentID: UUID, newProperty: Property.Resolved, oldProperty: Property.Resolved)
}

/// A struct that encapsulates a single, discrete change made by the user in Manual ECO mode.
/// It serves as a record for the timeline view and holds all information needed to apply the change later.
struct ChangeRecord: Identifiable, Hashable, Codable {
    var id: UUID
    var timestamp: Date
    var source: ChangeSource
    var payload: ChangeType

    init(id: UUID = UUID(), timestamp: Date = .now, source: ChangeSource, payload: ChangeType) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.payload = payload
    }
    
    /// Provides a user-friendly, human-readable description of the change.
    /// This is used for display in the ECO timeline UI.
    var description: String {
        // Note: To get component names (e.g., "R5"), we'll need access to the ProjectManager or the design model.
        // For now, we'll use placeholder text with IDs, to be enhanced in a later phase.
        switch payload {
        case .updateReferenceDesignator(let componentID, let newIndex, _):
            // In a real implementation, you'd look up the component's prefix.
            return "Set RefDes for component \(componentID.uuidString.prefix(4))... to \(newIndex)"
            
        case .assignFootprint(let componentID, _, let newFootprintName, _):
            let componentStr = "component \(componentID.uuidString.prefix(4))..."
            if let newFootprintName = newFootprintName {
                return "Assign Footprint '\(newFootprintName)' to \(componentStr)"
            } else {
                return "Unassign Footprint from \(componentStr)"
            }
            
        case .updateProperty(let componentID, let newProperty, _):
            let componentStr = "component \(componentID.uuidString.prefix(4))..."
            return "Update \(newProperty.key.label) for \(componentStr) to \(newProperty.value.description)"
        }
    }
}

