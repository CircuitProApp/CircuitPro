//
//  NetNavigatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/22/25.
//

import SwiftUI

struct NetNavigatorView: View {
    
    @BindableEnvironment(\.projectManager)
    private var projectManager
    
    var document: CircuitProjectFileDocument
    
    var body: some View {
        
        let sortedNets = projectManager.schematicGraph.nets().sorted {
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
                // 2. Use the new `component(for:)` helper for a cleaner implementation.
                let allEdgesOfSelectedNets = newSelection.flatMap { netID in
                    projectManager.schematicGraph.component(for: netID).edges
                }
                
                // Preserve any selected symbols (which are not edges).
                let currentSymbolSelection = projectManager.selectedNodeIDs.filter {
                    projectManager.schematicGraph.edges[$0] == nil
                }
                
                // Set the main selection to be the selected symbols plus the edges from the selected nets.
                projectManager.selectedNodeIDs = currentSymbolSelection.union(allEdgesOfSelectedNets)
            }
        }
    }
}
