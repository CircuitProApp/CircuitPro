// Features/Workspace/Navigator/NetNavigatorView.swift (Corrected)

import SwiftUI

struct NetNavigatorView: View {
    
    @BindableEnvironment(\.projectManager)
    private var projectManager
    
    var body: some View {
        
        // MODIFICATION: Access schematicGraph through the new controller.
        let graph = projectManager.schematicController.schematicGraph
        
        let sortedNets = graph.nets().sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        
        if sortedNets.isEmpty {
            VStack {
                Text("No Nets")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(sortedNets, id: \.id, selection: $projectManager.selectedNetIDs) { net in
                Text(net.name)
                    .frame(height: 14)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
            .onChange(of: projectManager.selectedNetIDs) { _, newSelection in
                // MODIFICATION: Use the same `graph` variable for consistency.
                let allEdgesOfSelectedNets = newSelection.flatMap { netID in
                    graph.component(for: netID).edges
                }
                
                // Preserve any selected symbols (which are not edges).
                let currentSymbolSelection = projectManager.selectedNodeIDs.filter {
                    graph.edges[$0] == nil
                }
                
                // Set the main selection to be the selected symbols plus the edges from the selected nets.
                projectManager.selectedNodeIDs = currentSymbolSelection.union(allEdgesOfSelectedNets)
            }
        }
    }
}
