//
//  InspectorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI
import SwiftDataPacks // Required to use @PackManager

struct InspectorView: View {
    
    @Environment(\.projectManager)
    private var projectManager
    
    // 1. Get the PackManager from the environment to fetch component definitions.
    @PackManager private var packManager
    
    @State private var selectedTab: InspectorTab = .attributes
    
    /// A computed property that attempts to find the selected node.
    private var singleSelectedNode: BaseNode? {
        guard projectManager.selectedNodeIDs.count == 1,
              let selectedID = projectManager.selectedNodeIDs.first else {
            return nil
        }
        return projectManager.canvasNodes.findNode(with: selectedID)
    }
    
    /// A computed property that finds both the symbol node AND its corresponding DesignComponent.
    /// This is the key piece of logic that connects the canvas selection to the data model.
    @MainActor private var selectedComponentContext: (component: DesignComponent, node: SymbolNode)? {
        // Ensure the selected node is a SymbolNode
        guard let symbolNode = singleSelectedNode as? SymbolNode else {
            return nil
        }
        
        // Use the project manager to get the list of all design components
        let components = projectManager.designComponents(using: packManager)
        
        // Find the specific component that matches our selected node's ID
        if let component = components.first(where: { $0.id == symbolNode.id }) {
            return (component, symbolNode)
        }
        
        return nil
    }
    
    var body: some View {
        @Bindable var manager = projectManager
        
        VStack(alignment: .leading, spacing: 0) {
            
            // 2. Check for the rich context object first.
            if let context = selectedComponentContext {
                SymbolNodeInspectorHostView(
                    component: context.component,
                    symbolNode: context.node,
                    selectedTab: $selectedTab // Pass the binding for tab selection
                )
            } else if singleSelectedNode != nil {
                // 3. Handle cases where an item is selected, but it's not a component
                //    (e.g., a wire or a net label).
                Text("Properties for this element type are not yet implemented.")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 4. Handle no selection or multiple selection.
                VStack {
                    Spacer()
                    Text(manager.selectedNodeIDs.isEmpty ? "No Selection" : "Multiple Items Selected")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
