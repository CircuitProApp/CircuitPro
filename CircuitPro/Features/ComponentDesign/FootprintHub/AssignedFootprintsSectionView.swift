//
//  AssignedFootprintsSectionView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct AssignedFootprintsSectionView: View {
    
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    @Binding var hubSelectionID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assigned from Library")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            
            if componentDesignManager.assignedFootprints.isEmpty {
                Text("No footprints assigned.")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)], spacing: 16) {
                    ForEach(componentDesignManager.assignedFootprints) { footprint in
                        // CORRECTED: Uses the original FootprintCardView, passing the footprint's name
                        FootprintCardView(name: footprint.name)
                    }
                }
            }
        }
    }
}
