//
//  InspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI
// SwiftDataPacks is no longer needed here, as we are not fetching data.

struct InspectorView: View {
    
    @BindableEnvironment(\.projectManager) private var projectManager
    
    // The @PackManager is no longer needed in this view.
    
    @State private var selectedTab: InspectorTab = .attributes
    
    /// A computed property that attempts to find the selected node.
    private var singleSelectedNode: BaseNode? {
        guard projectManager.selectedNodeIDs.count == 1,
              let selectedID = projectManager.selectedNodeIDs.first else {
            return nil
        }
        return projectManager.canvasNodes.findNode(with: selectedID)
    }
    
    /// --- CORRECTED ---
    /// A computed property that finds both the symbol node AND its corresponding ComponentInstance.
    /// This is the key piece of logic that connects the canvas selection to the data model.
    private var selectedComponentContext: (component: ComponentInstance, node: SymbolNode)? {
        // Ensure the selected node is a SymbolNode
        guard let symbolNode = singleSelectedNode as? SymbolNode else {
            return nil
        }
        
        // We no longer need to fetch or resolve anything.
        // We just find the instance in the project manager's list.
        if let componentInstance = projectManager.componentInstances.first(where: { $0.id == symbolNode.id }) {
            return (componentInstance, symbolNode)
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // The logic here remains the same, but the `context.component` is now a `ComponentInstance`.
            if let context = selectedComponentContext {
                
                // You will need to update `SymbolNodeInspectorHostView` to accept a `ComponentInstance`
                // instead of a `DesignComponent`.
                SymbolNodeInspectorHostView(
                    component: context.component, // This is now a ComponentInstance
                    symbolNode: context.node,
                    selectedTab: $selectedTab
                )

            }  else if let anchoredText = singleSelectedNode as? AnchoredTextNode {
            
                AnchoredTextInspectorView(anchoredText: anchoredText)
                
            } else if singleSelectedNode != nil {
                Text("Properties for this element type are not yet implemented.")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text(projectManager.selectedNodeIDs.isEmpty ? "No Selection" : "Multiple Items Selected")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
