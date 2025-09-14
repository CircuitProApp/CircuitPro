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
    
    /// A computed property that attempts to find the selected node from the currently active canvas.
    private var singleSelectedNode: BaseNode? {
        guard projectManager.selectedNodeIDs.count == 1,
              let selectedID = projectManager.selectedNodeIDs.first else {
            return nil
        }
        // --- MODIFIED: Use `activeCanvasNodes` to search the correct node list ---
        return projectManager.activeCanvasNodes.findNode(with: selectedID)
    }
    
    /// A computed property that finds the ComponentInstance for a selected SymbolNode.
    /// This is only relevant for the schematic editor.
    private var selectedComponentContext: (component: ComponentInstance, node: SymbolNode)? {
        // Ensure the selected node is a SymbolNode
        guard let symbolNode = singleSelectedNode as? SymbolNode else {
            return nil
        }
        
        // Find the corresponding data model instance
        if let componentInstance = projectManager.componentInstances.first(where: { $0.id == symbolNode.id }) {
            return (componentInstance, symbolNode)
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- MODIFIED: The view's logic is now structured by the active editor ---
            switch projectManager.selectedEditor {
            
            case .schematic:
                schematicInspectorView

            case .layout:
                layoutInspectorView
            }
        }
    }

    /// The view content to display when the Schematic editor is active.
    @ViewBuilder
    private var schematicInspectorView: some View {
        if let context = selectedComponentContext {
            SymbolNodeInspectorHostView(
                component: context.component,
                symbolNode: context.node,
                selectedTab: $selectedTab
            )
            .id(context.component.id)

        } else if let anchoredText = singleSelectedNode as? AnchoredTextNode {
            AnchoredTextInspectorView(anchoredText: anchoredText)
            
        } else {
            // Fallback for schematic (e.g., wires, junctions, etc.) or multi-selection
            selectionStatusView
        }
    }

    /// The view content to display when the Layout editor is active.
    @ViewBuilder
    private var layoutInspectorView: some View {
        if singleSelectedNode != nil {
            // We have a single selection (e.g., a FootprintNode or PadNode).
            // Since the layout inspector isn't built, show a placeholder.
            Text("Layout inspector not yet implemented.")
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Handle no selection or multi-selection for layout.
            selectionStatusView
        }
    }
    
    /// A shared view for displaying the current selection status (none, or multiple).
    @ViewBuilder
    private var selectionStatusView: some View {
        VStack {
            Spacer()
            Text(projectManager.selectedNodeIDs.isEmpty ? "No Selection" : "Multiple Items Selected")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// --- HELPER EXTENSION (Assuming this exists, if not, it should be added) ---
// This helper makes finding a node in a tree structure cleaner.
extension Array where Element == BaseNode {
    func findNode(with id: UUID) -> BaseNode? {
        for node in self {
            if node.id == id {
                return node
            }
            if let foundInChildren = node.children.findNode(with: id) {
                return foundInChildren
            }
        }
        return nil
    }
}
