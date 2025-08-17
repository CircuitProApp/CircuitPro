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
    
    @State private var selectedMode: LibraryMode = .all
    
    // Kept the @Query as you requested.
    private var components: [Component] = []
    
    // Filters components based on search text. This remains the same.
    private var filteredComponents: [Component] {
        if searchText.isEmpty {
            return components
        } else {
            return components.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // A computed property to easily find the full Component object from the selected ID.
    @State private var selectedComponent: Component?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibrarySearchView(searchText: $searchText)
            Divider()
            LibraryModeView(selectedMode: $selectedMode)
            Divider()
            
            HStack(spacing: 0) {
                // Using List with a selection binding is the standard SwiftUI way to create a selectable list.
                // It's lazy and handles row highlighting automatically.
                Group {
                    switch selectedMode {
                    case .all:
                        LibraryListView(filteredComponents: filteredComponents, selectedComponentID: $selectedComponentID)
                        
                    case .user:
                        Text("Jello")
                    case .packs:
                        PacksView()
                    }
                }
                .frame(width: 272)
                .frame(maxHeight: .infinity)
          
                Divider()
                
                // This is the detail view. It now dynamically updates based on the selection.
               LibraryDetailView(selectedComponent: $selectedComponent)
            }
        }
        .frame(minWidth: 682, minHeight: 373)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 10))
    }
}
