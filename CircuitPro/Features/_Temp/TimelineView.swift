//
//  TimelineView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.projectManager) private var projectManager
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allFootprints: [FootprintDefinition]
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            if projectManager.syncManager.pendingChanges.isEmpty {
                ContentUnavailableView("No Pending Changes", systemImage: "checklist")
            } else {
                List(projectManager.syncManager.pendingChanges) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.description)
                            .fontWeight(.medium)
                        HStack {
                            Image(systemName: record.source == .schematic ? "doc.plaintext" : "square.grid.3x3")
                            Text(record.timestamp, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.sidebar)
            }
            
            Divider()
            
            footer
        }
        .frame(minWidth: 500, minHeight: 400, idealHeight: 600)
    }
    
    private var header: some View {
        Text("Pending Changes")
            .font(.headline)
            .padding()
    }
    
    private var footer: some View {
        HStack {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            
            Spacer()
            
            // --- ADDED: The new "Discard All" button ---
            Button("Discard All", role: .destructive) {
                // It calls our new ProjectManager function.
                projectManager.discardPendingChanges()
                dismiss()
            }
            .tint(.red)
            // It should also be disabled if there's nothing to discard.
            .disabled(projectManager.syncManager.pendingChanges.isEmpty)
            
            Button("Apply \(projectManager.syncManager.pendingChanges.count) Changes") {
                projectManager.applyChanges(
                    projectManager.syncManager.pendingChanges,
                    allFootprints: allFootprints
                )
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(projectManager.syncManager.pendingChanges.isEmpty)
        }
        .padding()
    }
}
