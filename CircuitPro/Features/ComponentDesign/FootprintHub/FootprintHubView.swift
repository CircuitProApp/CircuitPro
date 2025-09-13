import SwiftUI

struct FootprintHubView: View {
    
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    @State private var showFootprintsSheet: Bool = false
    @State private var hubSelectionID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header Controls
            HStack(spacing: 12) {
                actionButton("Create New", systemImage: "plus") {
                    componentDesignManager.addNewFootprint()
                }
                actionButton("Assign Existing", systemImage: "magnifyingglass") {
                    showFootprintsSheet.toggle()
                }
                Spacer()
            }
            .padding()

            Divider()

            // MARK: - Content Area
            if componentDesignManager.footprintDrafts.isEmpty && componentDesignManager.assignedFootprints.isEmpty {
                ContentUnavailableView(
                    "No Footprints Created",
                    systemImage: "square.dashed",
                    description: Text("Click 'Create New' or 'Assign Existing' to add a footprint.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        NewFootprintsSectionView(
                            hubSelectionID: $hubSelectionID,
                            onOpen: { draft in
                                // Trigger navigation by setting the selected ID in the manager
                                componentDesignManager.selectedFootprintID = draft.id
                            }
                        )
                        
                        AssignedFootprintsSectionView(
                            hubSelectionID: $hubSelectionID
                        )
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showFootprintsSheet) {
            Text("Assign Existing Footprint (Not Implemented)")
                .frame(minWidth: 400, minHeight: 300)
        }
    }
    
    @ViewBuilder
    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .padding(10)
            .foregroundStyle(.blue)
            .background(.quaternary)
            .contentShape(.rect)
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
