//
//  SyncManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import Foundation
import Observation

/// Manages the application's data synchronization mode and holds pending changes.
///
/// This observable class acts as the source of truth for whether changes should be
/// applied instantly (`.automatic`) or queued for later review (`.manualECO`).
@Observable
final class SyncManager {
    
    /// The current operational mode for data synchronization.
    var syncMode: SyncMode = .manualECO
    
    /// An array of changes that have been made but not yet applied to the main data model.
    /// This array is populated only when `syncMode` is `.manualECO`.
    var pendingChanges: [ChangeRecord] = []
    
    /// Adds a new change to the pending changes list.
    /// - Parameter record: The `ChangeRecord` to add.
    func addChange(_ record: ChangeRecord) {
        // Prepending the change so the latest appears at the top of a list.
        pendingChanges.insert(record, at: 0)
        
        // In a complete implementation, this would likely trigger a UI update,
        // such as showing a badge indicating the number of pending changes.
        print("Change recorded. Total pending changes: \(pendingChanges.count)")
    }
    
    /// Clears all pending changes from the list.
    /// This would be called after a user explicitly applies or discards the changes.
    func clearChanges() {
        pendingChanges.removeAll()
    }
    
    func removeChanges(withIDs ids: Set<UUID>) {
        pendingChanges.removeAll { ids.contains($0.id) }
    }
}

extension SyncManager {
    /// Finds the most recent pending change for a specific component that matches a given payload type.
    /// - Parameter componentID: The UUID of the component to search for.
    /// - Parameter changeIdentifier: A closure that returns true if the payload is the type we're looking for.
    /// - Returns: The `ChangeRecord` if a matching pending change is found, otherwise `nil`.
    func findLatestPendingChange(for componentID: UUID, matching changeIdentifier: (ChangeType) -> Bool) -> ChangeRecord? {
        // pendingChanges is sorted with the newest first, so the first match is the latest.
        return pendingChanges.first { record in
            switch record.payload {
            case .updateReferenceDesignator(let id, _, _),
                 .assignFootprint(let id, _, _, _),
                 .updateProperty(let id, _, _):
                
                // Check if the change is for the correct component
                guard id == componentID else { return false }
                
                // Check if it's the correct type of change
                return changeIdentifier(record.payload)
            }
        }
    }
}

extension SyncManager {
    /// A helper to identify the "type" of a change, ignoring its associated values.
    /// This is used to find if a change for the same property already exists.
    private enum ChangeIdentifier {
        case refdes, footprint, property(id: UUID)
    }
    
    private func getIdentifier(for payload: ChangeType) -> ChangeIdentifier {
        switch payload {
        case .updateReferenceDesignator:
            return .refdes
        case .assignFootprint:
            return .footprint
        case .updateProperty(_, let newProperty, _):
            return .property(id: newProperty.id)
        }
    }

    /// Updates an existing pending change for the same property, or inserts the record if none exists.
    /// This prevents duplicate change records for the same action.
    /// - Parameter record: The `ChangeRecord` to upsert.
    func upsertChange(_ record: ChangeRecord) {
        let newPayload = record.payload
        let (componentID, newIdentifier) = {
            switch newPayload {
            case .updateReferenceDesignator(let id, _, _):
                return (id, getIdentifier(for: newPayload))
            case .assignFootprint(let id, _, _, _):
                return (id, getIdentifier(for: newPayload))
            case .updateProperty(let id, _, _):
                return (id, getIdentifier(for: newPayload))
            }
        }()

        // Attempt to find an existing change for this exact component and property type.
        if let existingIndex = pendingChanges.firstIndex(where: { existingRecord in
            // Check if the component ID matches
            let sameComponent = switch existingRecord.payload {
            case .updateReferenceDesignator(let id, _, _),
                 .assignFootprint(let id, _, _, _),
                 .updateProperty(let id, _, _):
                id == componentID
            }
            
            guard sameComponent else { return false }
            
            // Check if the property identifier matches
            let existingIdentifier = getIdentifier(for: existingRecord.payload)
            
            switch (newIdentifier, existingIdentifier) {
            case (.refdes, .refdes), (.footprint, .footprint):
                return true
            case (.property(let newID), .property(let oldID)):
                return newID == oldID
            default:
                return false
            }
        }) {
            // If we found one, replace it with the new record.
            // This preserves the timestamp of the latest edit.
            pendingChanges[existingIndex] = record
            print("Change updated. Total pending changes: \(pendingChanges.count)")
        } else {
            // Otherwise, insert the new record at the front.
            addChange(record)
        }
    }
}
