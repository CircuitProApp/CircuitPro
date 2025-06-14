//
//  WorkspaceView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/1/25.
//

import SwiftUI
import SwiftData

struct WorkspaceView: View {
    
    @Environment(\.projectManager)
    private var projectManager

    var document: CircuitProjectDocument
    
    @State private var showInspector: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigatorView(document: document)
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
            EditorView(document: document)
          
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
                Text("Jello")
            }
                .inspectorColumnWidth(min: 260, ideal: 260, max: 1000)
        }
        .onAppear {
            if projectManager.project.designs.isNotEmpty {
                projectManager.selectedDesign = projectManager.project.designs.first!
            }
       
        }
    }
}

