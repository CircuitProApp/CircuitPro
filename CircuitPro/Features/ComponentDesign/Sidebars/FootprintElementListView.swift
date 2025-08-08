// Features/ComponentDesign/Sidebars/FootprintElementListView.swift

import SwiftUI

struct FootprintElementListView: View {
    /// The manager that holds the state for the canvas editor.
    /// This should be passed in from the parent view.
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    var editor: CanvasEditorManager {
        componentDesignManager.footprintEditor
    }

    /// A type-safe identifier for any selectable item in the outline.
    /// Using AnyHashable allows us to use layer IDs and element IDs directly.
    typealias OutlineItemID = AnyHashable

    /// The identifiable data model for the hierarchical list.
    struct OutlineItem: Identifiable {
        /// The unique ID for the item, which can be a layer's UUID or an element's UUID.
        let id: OutlineItemID
        /// The content of the item, either a layer or a canvas element.
        let content: Content
        /// The children of this item, used for layer grouping.
        let children: [OutlineItem]?
        
        enum Content {
            case layer(CanvasLayer)
            case element(BaseNode)
        }
    }
    
    /// The `List`'s current selection. Binds to OutlineItemID.
    @State private var selection: Set<OutlineItemID> = []
    
    /// The set of layer IDs that are currently expanded in the UI.
    @State private var expandedLayers: Set<UUID> = []
    
    private var sortedLayers: [CanvasLayer] {
        editor.layers.sorted { lhs, rhs in
            if lhs.zIndex == rhs.zIndex {
                // Stable tie-breaker to avoid jitter
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            // Higher zIndex first (top-most first in the list)
            return lhs.zIndex < rhs.zIndex
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Footprint Elements")
                .font(.title3.weight(.semibold))
                .padding(10)
            
            // A hierarchical list that gets its data and children structure from outlineData.
            List(outlineData, children: \.children, selection: $selection) { item in
                switch item.content {
                case .layer(let layer):
                    // Renders the view for a layer row.
                    layerRow(for: layer)
                case .element(let element):
                    // Renders the view for a canvas element row.
                    // This assumes CanvasElementRowView is compatible with your BaseNode.
                    CanvasElementRowView(element: element, editor: editor)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            // Your existing view for adding text sources.
            DynamicTextSourceListView(editor: editor)
        }
        // Respond to changes in the UI selection.
        .onChange(of: selection) { handleSelectionChange() }
        // Respond to programmatic changes from the manager.
        .onChange(of: editor.activeLayerId) { syncSelectionFromManager() }
        .onChange(of: editor.selectedElementIDs) { syncSelectionFromManager() }
        .onAppear {
            // Set the initial selection and expansion state when the view appears.
            syncSelectionFromManager()
            expandedLayers = Set(editor.layers.map { $0.id })
            print(editor.layers)
        }
    }
    
    // MARK: - View Builders

    /// Creates the visual representation for a layer row in the list.
    @ViewBuilder
    private func layerRow(for layer: CanvasLayer) -> some View {
        HStack {
            // Layer Color Swatch
            Image(systemName: "circle.fill")
                .foregroundStyle(Color(cgColor: layer.color))
            
            Text(layer.name)
                .fontWeight(.semibold)
                
            Spacer()
        }
        .contentShape(Rectangle()) // Ensures the entire row is tappable
    }
    
    // MARK: - Data Source

    /// Assembles the hierarchical data structure for the `List`.
    private var outlineData: [OutlineItem] {
        let elementsByLayer = Dictionary(grouping: editor.elements) { node in
            (node as? Layerable)?.layerId
        }

        // Use sortedLayers instead of editor.layers
        let items = sortedLayers.map { layer -> OutlineItem in
            let childElements = (elementsByLayer[layer.id] ?? []).map { element in
                OutlineItem(id: element.id, content: .element(element), children: nil)
            }
            return OutlineItem(id: layer.id, content: .layer(layer), children: childElements)
        }
        
        return items
    }
    
    // MARK: - Selection Synchronization Logic
    
    /// Updates the `CanvasEditorManager` when the user changes the selection in the list.
    private func handleSelectionChange() {
        // Find the first selected ID that belongs to a layer.
        let selectedLayerId = selection.compactMap { $0 as? UUID }.first { id in
            editor.layers.contains(where: { $0.id == id })
        }

        if let selectedLayerId = selectedLayerId {
            // If a layer was selected, it becomes the active layer.
            editor.activeLayerId = selectedLayerId
            editor.selectedElementIDs = []
            
            // Enforce a single layer selection in the UI. If the user shift-clicks,
            // we revert to selecting only the first layer clicked.
            if selection.count > 1 || selection.first as! UUID != selectedLayerId {
                DispatchQueue.main.async {
                    self.selection = [selectedLayerId]
                }
            }
        } else {
            // If no layer is selected, then only elements are selected.
            editor.activeLayerId = nil
            editor.selectedElementIDs = Set(selection.compactMap { $0 as? UUID })
        }
    }
    
    /// Updates the list's selection when the manager's state changes from another source
    /// (e.g., clicking on the canvas).
    private func syncSelectionFromManager() {
        var newSelection: Set<OutlineItemID> = []
        if let activeLayerId = editor.activeLayerId {
            // If there's an active layer, it's the only thing selected.
            newSelection.insert(activeLayerId)
        } else {
            // Otherwise, the selection is the set of selected element IDs.
            editor.selectedElementIDs.forEach { newSelection.insert($0) }
        }
        
        // Only update the state if it has actually changed to prevent cycles.
        if self.selection != newSelection {
            self.selection = newSelection
        }
    }
}
