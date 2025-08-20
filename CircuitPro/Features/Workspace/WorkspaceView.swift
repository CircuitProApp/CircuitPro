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
    
    @Query private var components: [Component]

    
    var document: CircuitProjectFileDocument
    
    @State private var showInspector: Bool = false
    @State private var showFeedbackSheet: Bool = false
    @State private var isShowingLibrary: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    @State private var showingUpdateAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
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
                   
                }
        }
        .frame(minWidth: 800, minHeight: 600)
        .inspector(isPresented: $showInspector) {
            InspectorView()
            .inspectorColumnWidth(min: 200, ideal: 260, max: 1000)
            .toolbar {
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
        .onAppear {
            if projectManager.project.designs.isNotEmpty {
                projectManager.selectedDesign = projectManager.project.designs.first!
            }
            for component in components {
                print(component.name)
            }
        }
        .onAppear {
#if !DEBUG
//            Task {
//                do {
//                    if let newVersion = try await LibraryUpdater.checkForUpdates() {
//                        alertTitle = "Library Updated"
//                        // The new, more accurate message:
//                        alertMessage = "The component library has been successfully updated to version \(newVersion) and is ready to use."
//                        showingUpdateAlert = true
//                    }
//                } catch {
//                    // If an error occurred, show an error alert
//                    alertTitle = "Update Failed"
//                    alertMessage = "Could not update the component library. Please check your internet connection and try again later. Error: \(error.localizedDescription)"
//                    showingUpdateAlert = true
//                }
//            }
#endif
        }
        .alert(isPresented: $showingUpdateAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        
    }
}

