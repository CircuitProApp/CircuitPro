//
//  LibraryPanelView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import SwiftData

struct LibraryPanelView: View {
    
    @State private var selectedComponentID: UUID?
    
    @State private var selectedMode: LibraryMode = .all
    
    // A computed property to easily find the full Component object from the selected ID.
    @State private var selectedComponent: Component?
    
    @State private var libraryManager: LibraryManager = LibraryManager()
    
    var body: some View {
        @Bindable var bindableManager = libraryManager
        VStack(alignment: .leading, spacing: 0) {
            LibrarySearchView(searchText: $bindableManager.searchText)
            Divider()
            LibraryModeView(selectedMode: $selectedMode)
            Divider()
            HStack(spacing: 0) {
                Group {
                    switch selectedMode {
                    case .all:
                        AllComponentsView()
                    case .user:
                        UserComponentsView()
                            .filterContainer(for: .mainStore)
                    case .packs:
                        PacksView()
                    }
                }
                .frame(width: 272)
                .frame(maxHeight: .infinity)
                Divider()
                Group {
                    switch selectedMode {
                    case .all, .user:
                       ComponentDetailView(selectedComponent: $selectedComponent)
                    case .packs:
                        Text("Pack detail view goes here")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 682, minHeight: 373)
        .background {
            HUDWindowBackgroundMaterial()
        }
        .clipShape(.rect(cornerRadius: 10))
        .environment(libraryManager)
    }
}
