//
//  LibraryPanelView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import SwiftData

struct LibraryPanelView: View {
    
    @State private var searchText: String = ""
    
    // This state variable will store the ID of the selected component.
    // It's optional because nothing is selected at first.
    @State private var selectedComponentID: UUID?

    @Environment(\.modelContext)
    private var modelContext
    
    // Kept the @Query as you requested.
    @Query(
        filter: #Predicate<Component> { component in
            true
        },
        sort: [SortDescriptor(\.name, order: .forward)]
    )
    private var components: [Component]
    
    // Filters components based on search text. This remains the same.
    private var filteredComponents: [Component] {
        if searchText.isEmpty {
            return components
        } else {
            return components.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // A computed property to easily find the full Component object from the selected ID.
    private var selectedComponent: Component? {
        if let selectedID = selectedComponentID {
            // Find the first component in the main array that matches the selected ID.
            return components.first { $0.uuid == selectedID }
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibrarySearchView(searchText: $searchText)
            Divider()
//            HStack(spacing: 10) {
//                Image(systemName: "square")
//                Image(systemName: "triangle")
//                Image(systemName: "circle")
//            }
//            .frame(maxWidth: .infinity)
//            .foregroundStyle(.secondary)
//            .padding(10)
//            .font(.title3)
//            Divider()
            
            HStack(spacing: 0) {
                // Using List with a selection binding is the standard SwiftUI way to create a selectable list.
                // It's lazy and handles row highlighting automatically.
                LibraryListView(filteredComponents: filteredComponents, selectedComponentID: $selectedComponentID)
                Divider()
                
                // This is the detail view. It now dynamically updates based on the selection.
                VStack {
                    // Check if we have a selected component.
                    if let component = selectedComponent {
                        // If one is selected, display its name.
                        Text(component.name)
                            .font(.title)
                            .foregroundStyle(.primary)
                        // You could add more details here later.
                        Text("Category: \(component.category.label)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        // If nothing is selected, show the placeholder text.
                        Text("Nothing Selected")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 682, minHeight: 373)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 10))
    }
}
