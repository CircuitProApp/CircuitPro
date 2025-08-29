//
//  InspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

struct InspectorView: View {
    
    @BindableEnvironment(\.projectManager) private var projectManager

    
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
        
        if let componentInstance = projectManager.componentInstances.first(where: { $0.id == symbolNode.id }) {
            return (componentInstance, symbolNode)
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let context = selectedComponentContext {
                SymbolNodeInspectorHostView(
                    component: context.component,
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
