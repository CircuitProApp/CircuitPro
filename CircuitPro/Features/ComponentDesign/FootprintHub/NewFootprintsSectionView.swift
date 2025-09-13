//
//  NewFootprintsSectionView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct NewFootprintsSectionView: View {
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    @Binding var hubSelectionID: UUID?
    
    let onOpen: (FootprintDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Footprints")
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            if componentDesignManager.footprintDrafts.isEmpty {
                Text("No new footprints created.")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)], spacing: 16) {
                    ForEach(componentDesignManager.footprintDrafts) { draft in
                        FootprintCardView(name: draft.name)
                            .onTapGesture {
                                self.onOpen(draft)
                            }
                            // ADDED: Context menu for each card
                            .contextMenu {
                                Button(role: .destructive) {
                                    // Action to remove the specific draft
                                    removeDraft(draft)
                                } label: {
                                    Label("Remove Footprint", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
    
    /// A helper function to call the manager to remove a specific draft.
    private func removeDraft(_ draft: FootprintDraft) {
        componentDesignManager.footprintDrafts.removeAll { $0.id == draft.id }
        
        // If the removed draft was the one being edited, this will safely deselect it.
        if componentDesignManager.selectedFootprintID == draft.id {
            componentDesignManager.selectedFootprintID = nil
        }
    }
}
