//
//  NetNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/22/25.
//

import SwiftUI

struct NetNavigatorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    var document: CircuitProjectDocument
    
    var body: some View {
        @Bindable var bindableProjectManager = projectManager
        
        let sortedNets = projectManager.schematicGraph.findNets().sorted {
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

            
            List(sortedNets, id: \.id, selection: $bindableProjectManager.selectedNetIDs) { net in
                Text(net.name)
                    .frame(height: 14)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
            .onChange(of: bindableProjectManager.selectedNetIDs) { _, newSelection in
                // Get all edges for the selected nets
                let allEdgesOfSelectedNets = newSelection.flatMap { netID -> [UUID] in
                    if let vertexInNet = projectManager.schematicGraph.vertices.values.first(where: { $0.netID == netID }) {
                        let (_, edgeIDs) = projectManager.schematicGraph.net(startingFrom: vertexInNet.id)
                        return Array(edgeIDs)
                    }
                    return []
                }
                
                // Preserve any selected symbols (non-edges)
                let currentSymbolSelection = projectManager.selectedComponentIDs.filter { projectManager.schematicGraph.edges[$0] == nil }
                
                // Set the main selection to be the selected symbols plus the edges from the selected nets
                projectManager.selectedComponentIDs = currentSymbolSelection.union(allEdgesOfSelectedNets)
            }
        }
    }
}
