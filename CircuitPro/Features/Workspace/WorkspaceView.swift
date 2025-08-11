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
    @State private var showFeedbackSheet: Bool = false
    @State private var isShowingLibrary: Bool = false
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
                        Image(systemName: CircuitProSymbols.Workspace.sidebarLeading)
                            .imageScale(.large)
                    }
                }
            }
        } detail: {
            EditorView(document: document)
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
                            Image(systemName: CircuitProSymbols.Workspace.feedbackBubble)
                                .imageScale(.large)
                        }
                        .help("Send Feedback")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            self.showInspector.toggle()
                        } label: {
                            Image(systemName: CircuitProSymbols.Workspace.sidebarTrailing)
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

