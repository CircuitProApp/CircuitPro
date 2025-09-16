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

    var document: CircuitProjectFileDocument
    
    @State private var showInspector: Bool = false
    @State private var showFeedbackSheet: Bool = false
    @State private var isShowingLibrary: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigatorView(document: document)
                .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 320)
        } detail: {
            EditorView(document: document)
                .frame(minWidth: 320)
             
                .sheet(isPresented: $showFeedbackSheet) {
                    FeedbackFormView()
                        .frame(minWidth: 400, minHeight: 300)
                }
                .libraryPanel(isPresented: $isShowingLibrary)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingLibrary.toggle()
                        } label: {
                            Image(systemName: "plus")
                                .imageScale(.large)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showFeedbackSheet.toggle()
                        } label: {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .imageScale(.large)
                        }
                        .help("Send Feedback")
                    }
                   
                }
        }
        .frame(minWidth: 820, minHeight: 600)
        .inspector(isPresented: $showInspector) {
            InspectorView()
            .inspectorColumnWidth(min: 260, ideal: 300, max: 500)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        self.showInspector.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                            .imageScale(.large)
                    }
                }
            }
        }
        .onAppear {
            if let firstDesign = projectManager.project.designs.first {
                projectManager.selectedDesign = firstDesign
            }
        }
    }
}

