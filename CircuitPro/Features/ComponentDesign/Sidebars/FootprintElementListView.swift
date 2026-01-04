import SwiftUI

struct FootprintElementListView: View {
    // The view now directly receives the correct editor for the
    // currently selected footprint from the environment.
    @Environment(CanvasEditorManager.self) private var editor

    /// A type-safe identifier for any selectable item in the outline.
    typealias OutlineItemID = AnyHashable

    /// The identifiable data model for the hierarchical list.
    struct OutlineItem: Identifiable {
        let id: OutlineItemID
        let content: Content
        let children: [OutlineItem]?

        enum Content {
            case layer(any CanvasLayer)
            case element(CanvasEditorManager.ElementItem)
        }
    }

    /// The `List`'s current selection. Binds to OutlineItemID.
    @State private var selection: Set<OutlineItemID> = []

    /// The set of layer IDs that are currently expanded in the UI.
    /// This state variable now controls the DisclosureGroups.
    @State private var expandedLayers: Set<UUID> = []

    /// Tracks node IDs to detect when new elements are added.
    @State private var previousItemIDs: Set<UUID> = []

    private var sortedLayers: [any CanvasLayer] {
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
                .font(.headline)
                .padding(10)

            // Reverted to a List with ForEach and explicit DisclosureGroup to control expansion.
            List(selection: $selection) {
                ForEach(outlineData) { item in
                    if case .layer(let layer) = item.content {
                        disclosureGroupRow(for: layer, children: item.children ?? [])
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            TextSourceListView(editor: editor)
        }
        // This logic remains unchanged and is compatible with the new structure.
        .onChange(of: selection) { handleSelectionChange() }
        .onChange(of: editor.activeLayerId) { syncSelectionFromManager() }
        .onChange(of: editor.selectedElementIDs) { syncSelectionFromManager() }
        .onChange(of: editor.elementItems.count) { expandGroupForNewNodes() }
        .onAppear {
            syncSelectionFromManager()
            // This now correctly controls which disclosure groups start open.
            // Populating with all layer IDs will auto-expand all layers.
            expandedLayers = Set(editor.layers.map { $0.id })
            previousItemIDs = Set(editor.elementItems.map(\.id))
        }
    }

    // MARK: - View Builders

    /// Creates the DisclosureGroup for a layer and its children.
    @ViewBuilder
    private func disclosureGroupRow(for layer: any CanvasLayer, children: [OutlineItem]) -> some View {
        // Binding to control the expansion state of a single layer.
        let isExpandedBinding = Binding<Bool>(
            get: { self.expandedLayers.contains(layer.id) },
            set: { isExpanded in
                if isExpanded {
                    self.expandedLayers.insert(layer.id)
                } else {
                    self.expandedLayers.remove(layer.id)
                }
            }
        )

        DisclosureGroup(isExpanded: isExpandedBinding) {
            ForEach(children) { childItem in
                if case .element(let element) = childItem.content {
                    CanvasElementRowView(element: element)
                        .tag(childItem.id) // Tag elements for selection
                }
            }
        } label: {
            layerRow(for: layer)
                .tag(layer.id) // Tag the layer itself for selection
        }
    }

    /// Creates the visual representation for a layer row in the list.
    @ViewBuilder
    private func layerRow(for layer: any CanvasLayer) -> some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(Color(cgColor: layer.color))

            Text(layer.name)
                .fontWeight(.semibold)

            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Data Source

    /// Assembles the hierarchical data structure for the `List`. (Unchanged from your new code)
    private var outlineData: [OutlineItem] {
        let elementsByLayer = Dictionary(grouping: editor.elementItems) { item in
            item.layerId
        }

        let items = sortedLayers.map { layer -> OutlineItem in
            let childElements = (elementsByLayer[layer.id] ?? []).map { element in
                OutlineItem(id: element.id, content: .element(element), children: nil)
            }
            return OutlineItem(id: layer.id, content: .layer(layer), children: childElements)
        }

        return items
    }

    // MARK: - Change Handling

    /// When a new element is added to the canvas, expand its parent layer in the list.
    private func expandGroupForNewNodes() {
        let newNodes = editor.elementItems
        let newItemIDs = Set(newNodes.map(\.id))

        // An item was added.
        guard newItemIDs.count > previousItemIDs.count else {
            previousItemIDs = newItemIDs
            return
        }

        let addedItemIDs = newItemIDs.subtracting(previousItemIDs)

        // Create a lookup for the new nodes.
        let nodesByID = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.id, $0) })

        for id in addedItemIDs {
            if let newItem = nodesByID[id],
               let layerId = newItem.layerId {
                expandedLayers.insert(layerId)
            }
        }

        // Update the state for the next comparison.
        previousItemIDs = newItemIDs
    }

    // MARK: - Selection Synchronization Logic

    /// Updates the manager when the list selection changes.
    private func handleSelectionChange() {
        let selectedLayerId = selection.compactMap { $0 as? UUID }.first { id in
            editor.layers.contains(where: { $0.id == id })
        }

        if let selectedLayerId = selectedLayerId {
            // A layer was selected. Make it active and deselect elements.
            editor.activeLayerId = selectedLayerId
            editor.selectedElementIDs = []

            // Enforce single selection of the layer.
            if selection.count > 1 || (selection.first as? UUID) != selectedLayerId {
                DispatchQueue.main.async {
                    self.selection = [selectedLayerId]
                }
            }
        } else {
            // One or more elements were selected. Update selection but keep the active layer.
            editor.selectedElementIDs = Set(selection.compactMap { $0 as? UUID })
        }
    }

    /// Updates the list's selection from the manager's state.
    private func syncSelectionFromManager() {
        var newSelection: Set<OutlineItemID> = []

        // Prioritize element selection. If elements are selected, they should be highlighted.
        if !editor.selectedElementIDs.isEmpty {
            editor.selectedElementIDs.forEach { newSelection.insert($0) }
        }
        // Otherwise, if no elements are selected, highlight the active layer.
        else if let activeLayerId = editor.activeLayerId {
            newSelection.insert(activeLayerId)
        }

        // Only update the state if it has actually changed to prevent selection loops.
        if self.selection != newSelection {
            self.selection = newSelection
        }
    }
}
