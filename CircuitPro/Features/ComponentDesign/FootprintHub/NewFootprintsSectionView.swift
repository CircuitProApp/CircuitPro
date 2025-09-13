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
    
    // The closure correctly passes back a `FootprintDraft`
    let onOpen: (FootprintDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Footprints")
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            // Checks the new `footprintDrafts` array
            if componentDesignManager.footprintDrafts.isEmpty {
                Text("No new footprints created.")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)], spacing: 16) {
                    // Iterates over the array of `FootprintDraft` objects
                    ForEach(componentDesignManager.footprintDrafts) { draft in
                        // CORRECTED: Uses the original FootprintCardView, passing the draft's name
                        FootprintCardView(name: draft.name)
                            .onTapGesture {
                                self.onOpen(draft)
                            }
                    }
                }
            }
        }
    }
}
