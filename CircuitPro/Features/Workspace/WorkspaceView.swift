//
//  WorkspaceView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/1/25.
//

import SwiftUI
import SwiftData

struct WorkspaceView: View {
    @Environment(\.openWindow)
    private var openWindow

    var document: CircuitProjectDocument
    
    @State private var showInspector: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(document: document, project: document.model)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 1000)

            .toolbar {
                ToolbarItem(placement: .automatic   ) {
                    Button {
                        withAnimation {
                            if self.columnVisibility == .detailOnly {
                                self.columnVisibility = .all
                            } else {
                                self.columnVisibility = .detailOnly
                            }
                        }

                 
                        
                    } label: {
                        Image(systemName: AppIcons.sidebarLeading)
                            .imageScale(.large)
                    }
                }
            }
        } detail: {
            EditorView()
          
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            self.showInspector.toggle()
                        } label: {
                            Image(systemName: AppIcons.sidebarTrailing)
                                .imageScale(.large)
                        }
                    }
                }
        }

        .frame(minWidth: 800, minHeight: 600)
        .inspector(isPresented: $showInspector) {
            VStack {
                Text("JEllo")
            }
                .inspectorColumnWidth(min: 260, ideal: 260, max: 1000)
        }
    }
}

