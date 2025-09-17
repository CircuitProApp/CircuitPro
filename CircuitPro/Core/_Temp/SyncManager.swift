//
//  SyncManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import Foundation
import Observation

/// Manages synchronization mode and the list of pending changes (Manual ECO).
/// In Manual ECO, changes are recorded as `ChangeRecord`s instead of being
/// immediately applied to the model. Records are appended per user "commit"
/// (e.g., pressing Enter), and may be coalesced within that single commit by session.
@MainActor
@Observable
final class SyncManager {

    /// The current operational mode for data synchronization.
    var syncMode: SyncMode = .manualECO

    /// Newest-first list of pending changes. Each element represents one user commit.
    var pendingChanges: [ChangeRecord] = []

    // MARK: - Sessions

    /// Start a logical "user commit" session. Use this when a user confirms an edit
    /// (e.g., presses Enter, chooses a menu item, loses focus).
    /// Multiple setter calls that occur during the same commit should share this ID.
    func beginSession() -> UUID { UUID() }

    /// End a previously started session. Currently a no-op; used to demarcate boundaries.
    func endSession(_ id: UUID) { /* no-op; boundary marker for commit */ }

    // MARK: - Change list management

    /// Inserts a new change at the front (newest-first).
    func addChange(_ record: ChangeRecord) {
        pendingChanges.insert(record, at: 0)
        print("Change recorded. Total pending changes: \(pendingChanges.count)")
    }

    /// Remove all pending changes (used on Apply/Discard).
    func clearChanges() {
        pendingChanges.removeAll()
    }

    /// Remove a specific subset of pending changes by their IDs.
    func removeChanges(withIDs ids: Set<UUID>) {
        pendingChanges.removeAll { ids.contains($0.id) }
    }
}

// MARK: - Lookup utilities (used by resolvers)

extension SyncManager {
    /// Finds the most recent pending change for a specific component that matches the given payload type.
    /// - Parameters:
    ///   - componentID: The UUID of the component to search for.
    ///   - changeIdentifier: A predicate that returns true for the payload type we care about.
    /// - Returns: The latest `ChangeRecord` if found, else `nil`.
    func findLatestPendingChange(
        for componentID: UUID,
        matching changeIdentifier: (ChangeType) -> Bool
    ) -> ChangeRecord? {
        // `pendingChanges` is newest-first; the first match is the latest.
        return pendingChanges.first { record in
            switch record.payload {
            case .updateReferenceDesignator(let id, _, _),
                 .assignFootprint(let id, _, _, _),
                 .updateProperty(let id, _, _):
                return id == componentID && changeIdentifier(record.payload)
            }
        }
    }
}

// MARK: - Session-aware recording

extension SyncManager {
    /// A lightweight identifier for "which field" is being changed,
    /// used to coalesce duplicate writes within the same session.
    private enum ChangeIdentifier: Hashable {
        case refdes(UUID)             // component
        case footprint(UUID)          // component
        case property(UUID, UUID)     // component, property
    }

    /// Compute a coalescing key for a given change payload.
    private func identifier(for payload: ChangeType) -> ChangeIdentifier {
        switch payload {
        case .updateReferenceDesignator(let cid, _, _):
            return .refdes(cid)
        case .assignFootprint(let cid, _, _, _):
            return .footprint(cid)
        case .updateProperty(let cid, let prop, _):
            return .property(cid, prop.id)
        }
    }

    /// Append-only across sessions. Within the SAME session, keep only the last record
    /// for the same identifier (final value wins for that single user commit).
    /// Across different sessions, always append a new record (to preserve full history).
    ///
    /// - Parameters:
    ///   - source: Where the change originated (schematic/layout).
    ///   - payload: The specific change (with old/new values).
    ///   - sessionID: The current commit session ID; if nil, no coalescing occurs.
    func recordChange(source: ChangeSource, payload: ChangeType, sessionID: UUID?) {
        let rec = ChangeRecord(source: source, payload: payload, sessionID: sessionID)

        if let s = sessionID,
           let idx = pendingChanges.firstIndex(where: {
               $0.sessionID == s && identifier(for: $0.payload) == identifier(for: rec.payload)
           }) {
            // Same session + same field: replace the earlier record (final value wins for this commit).
            pendingChanges[idx] = rec
            print("Change updated (same session). Total pending changes: \(pendingChanges.count)")
        } else {
            // New session or different field: append as a new record (preserve full history).
            addChange(rec)
        }
    }

    /// Deprecated—use `recordChange(source:payload:sessionID:)` and pass a session.
    @available(*, deprecated, message: "Use recordChange(source:payload:sessionID:) with sessions.")
    func upsertChange(_ record: ChangeRecord) {
        recordChange(source: record.source, payload: record.payload, sessionID: record.sessionID)
    }
}
