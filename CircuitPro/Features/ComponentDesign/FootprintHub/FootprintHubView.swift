import SwiftUI

struct FootprintHubView: View {
    
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    @Environment(CanvasManager.self) private var footprintCanvasManager: CanvasManager
    
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
            }
            .padding()

            Divider()

            // MARK: - Content Area
            if componentDesignManager.newFootprints.isEmpty && componentDesignManager.assignedFootprints.isEmpty {
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
                            onOpen: { footprint in
                                componentDesignManager.navigationPath.append(footprint)
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
