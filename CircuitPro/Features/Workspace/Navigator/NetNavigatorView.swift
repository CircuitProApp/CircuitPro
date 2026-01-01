// Features/Workspace/Navigator/NetNavigatorView.swift (Corrected)

import SwiftUI

struct NetNavigatorView: View {

    @BindableEnvironment(\.editorSession)
    private var editorSession

    var body: some View {

        let graph = editorSession.schematicController.wireEngine

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
            List(sortedNets, id: \.id, selection: $editorSession.selectedNetIDs) { net in
                Text(net.name)
                    .frame(height: 14)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
            .onChange(of: editorSession.selectedNetIDs) { _, newSelection in
                let allEdgesOfSelectedNets = newSelection.flatMap { netID in
                    graph.component(for: netID).edges
                }

                let edgeSelection = allEdgesOfSelectedNets.map { GraphElementID.edge(EdgeID($0)) }
                let nodeSelection = editorSession.selectedNodeIDs.map { GraphElementID.node(NodeID($0)) }
                editorSession.schematicController.graph.selection = Set(edgeSelection + nodeSelection)
            }
        }
    }
}
