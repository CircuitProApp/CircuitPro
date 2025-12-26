// Features/Workspace/Navigator/NetNavigatorView.swift (Corrected)

import SwiftUI

struct NetNavigatorView: View {

    @BindableEnvironment(\.projectManager)
    private var projectManager

    var body: some View {

        let graph = projectManager.schematicController.wireEngine

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
                let allEdgesOfSelectedNets = newSelection.flatMap { netID in
                    graph.component(for: netID).edges
                }

                // Preserve any selected symbols (which are not edges).
                let currentSymbolSelection = projectManager.selectedNodeIDs.filter {
                    graph.edges[$0] == nil
                }

                projectManager.selectedNodeIDs = currentSymbolSelection
                projectManager.schematicController.graph.selection = Set(allEdgesOfSelectedNets.map(NodeID.init))
            }
        }
    }
}
