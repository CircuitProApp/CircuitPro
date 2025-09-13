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
                    ForEach(componentDesignManager.assignedFootprints, id: \.uuid) { footprint in
                        FootprintCardView(footprint: footprint)
                    }
                }
            }
        }
    }
}
