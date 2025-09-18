//
//  SyncManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import Foundation
import Observation

/// Manages synchronization mode and the list of pending changes (Manual ECO).
@MainActor
@Observable
final class SyncManager {

    /// The current operational mode for data synchronization.
    var syncMode: SyncMode = .manualECO

    /// Newest-first list of pending changes. Each element represents one user commit.
    var pendingChanges: [ChangeRecord] = []

    // MARK: - Sessions

    func beginSession() -> UUID { UUID() }
    func endSession(_ id: UUID) { /* no-op */ }

    // MARK: - Change list management

    func addChange(_ record: ChangeRecord) {
        pendingChanges.insert(record, at: 0)
        print("Change recorded. Total pending changes: \(pendingChanges.count)")
    }

    func clearChanges() {
        pendingChanges.removeAll()
    }

    func removeChanges(withIDs ids: Set<UUID>) {
        pendingChanges.removeAll { ids.contains($0.id) }
    }
    
    // --- (Phase 1): Value Resolver Logic now lives here ---
    
    func resolvedReferenceDesignator(for component: ComponentInstance, onlyFrom source: ChangeSource? = nil) -> Int {
        if syncMode == .automatic { return component.referenceDesignatorIndex }
        
        if let change = findLatestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .updateReferenceDesignator = $0 { return true }
            return false
        }),
           case .updateReferenceDesignator(_, let newIndex, _) = change.payload {
            return newIndex
        }
        return component.referenceDesignatorIndex
    }

    func resolvedFootprintName(for component: ComponentInstance, onlyFrom source: ChangeSource? = nil) -> String? {
        if syncMode == .automatic { return component.footprintInstance?.definition?.name }

        if let change = findLatestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .assignFootprint = $0 { return true }
            return false
        }),
           case .assignFootprint(_, _, let newName, _) = change.payload {
            return newName
        }
        return component.footprintInstance?.definition?.name
    }

    func resolvedFootprintUUID(for component: ComponentInstance, onlyFrom source: ChangeSource? = nil) -> UUID? {
        if syncMode == .automatic { return component.footprintInstance?.definitionUUID }
        
        if let change = findLatestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .assignFootprint = $0 { return true }
            return false
        }),
           case .assignFootprint(_, let newUUID, _, _) = change.payload {
            return newUUID
        }
        return component.footprintInstance?.definitionUUID
    }

    func resolvedProperty(for component: ComponentInstance, propertyID: UUID, onlyFrom source: ChangeSource? = nil) -> Property.Resolved? {
        guard let original = component.displayedProperties.first(where: { $0.id == propertyID }) else { return nil }
        if syncMode == .automatic { return original }

        if let change = findLatestPendingChange(for: component.id, onlyFrom: source, matches: {
            if case .updateProperty(_, let newProperty, _) = $0, newProperty.id == propertyID { return true }
            return false
        }),
           case .updateProperty(_, let newProperty, _) = change.payload {
            return newProperty
        }
        return original
    }
    
    /// Finds the most recent pending change for a specific component that matches the given payload type and optional source.
    private func findLatestPendingChange(
        for componentID: UUID,
        onlyFrom source: ChangeSource?,
        matches: (ChangeType) -> Bool
    ) -> ChangeRecord? {
        // `pendingChanges` is newest-first; the first match is the latest.
        return pendingChanges.first { record in
            // Use the new computed property for a clean check
            guard record.payload.componentID == componentID else { return false }
            // Optional source filter
            if let source, record.source != source { return false }
            // Payload match
            return matches(record.payload)
        }
    }
}

// MARK: - Session-aware recording

extension SyncManager {
    private enum ChangeIdentifier: Hashable {
        case refdes(UUID)
        case footprint(UUID)
        case property(UUID, UUID)
    }

    private func identifier(for payload: ChangeType) -> ChangeIdentifier {
        switch payload {
        case .updateReferenceDesignator(let cid, _, _): return .refdes(cid)
        case .assignFootprint(let cid, _, _, _): return .footprint(cid)
        case .updateProperty(let cid, let prop, _): return .property(cid, prop.id)
        }
    }

    func recordChange(source: ChangeSource, payload: ChangeType, sessionID: UUID?) {
        let rec = ChangeRecord(source: source, payload: payload, sessionID: sessionID)

        if let s = sessionID,
           let idx = pendingChanges.firstIndex(where: {
               $0.sessionID == s && identifier(for: $0.payload) == identifier(for: rec.payload)
           }) {
            pendingChanges[idx] = rec
            print("Change updated (same session). Total pending changes: \(pendingChanges.count)")
        } else {
            addChange(rec)
        }
    }
}

