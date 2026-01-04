// Features/Workspace/Navigator/NetNavigatorView.swift (Corrected)

import SwiftUI

struct NetNavigatorView: View {

    @BindableEnvironment(\.editorSession)
    private var editorSession

    var body: some View {
        // TEMP: Connections are disabled for now; keep the old net list logic for when we re-enable it.
        /*
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
        }
        */
        VStack(spacing: 8) {
            Text("Nets Disabled")
                .font(.callout)
            Text("Connection system is temporarily removed.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
