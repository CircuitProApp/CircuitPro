//
//  LibraryPanelView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import SwiftData

struct LibraryPanelView: View {
    
    @State private var libraryManager: LibraryManager = LibraryManager()
    
    var body: some View {
        @Bindable var bindableManager = libraryManager
        VStack(alignment: .leading, spacing: 0) {
            LibrarySearchView(searchText: $bindableManager.searchText)
            Divider()
            LibraryModeView(selectedMode: $bindableManager.selectedMode)
            Divider()
            HStack(spacing: 0) {
                Group {
                    switch libraryManager.selectedMode {
                    case .all:
                        ComponentListView()
                    case .user:
                        ComponentListView()
                            .filterContainer(for: .mainStore)
                    case .packs:
                        PacksView()
                    }
                }
                .frame(width: 272)
                .frame(maxHeight: .infinity)
                Divider()
                Group {
                    switch libraryManager.selectedMode {
                    case .all, .user:
                        ComponentDetailView()
                    case .packs:
                        PackDetailView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 682, minHeight: 373)
        .modify({ view in
            if #available(macOS 26, *) {
                view.background(GlassEffectView())
            } else {
                view
                    .background {
                        HUDWindowBackgroundMaterial()
                    }
                    .clipShape(.rect(cornerRadius: 10))
            }
        })
        .environment(libraryManager)
    }
}

import SwiftUI


@available(macOS 26.0, *)
struct GlassEffectView: NSViewRepresentable {
    var cornerRadius: CGFloat = 20
    var tintColor: NSColor? = nil
    
    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.cornerRadius = cornerRadius
        glassView.tintColor = tintColor
        
        // Note: Unlike NSVisualEffectView, NSGlassEffectView does not
        // currently have a public 'state' property to force an active look.
        // It automatically responds to window focus.
        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.tintColor = tintColor
    }
}
