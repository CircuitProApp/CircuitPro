//
//  WorkspaceView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/1/25.
//

import SwiftUI
import SwiftData

struct WorkspaceView: View {
    
    // The correct property wrapper for accessing an observable object from the environment.
    @BindableEnvironment(\.projectManager)
    private var projectManager

    private var syncManager: SyncManager {
        projectManager.syncManager
    }

    var document: CircuitProjectFileDocument
    
    @State private var showInspector: Bool = false
    @State private var showFeedbackSheet: Bool = false
    @State private var isShowingLibrary: Bool = false
    @State private var isShowingTimeline: Bool = false
    @State private var showDiscardChangesAlert: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    private var pendingChangesCount: String {
        let count = syncManager.pendingChanges.count
        return count > 99 ? "99+" : "\(count)"
    }
    
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
                .sheet(isPresented: $isShowingTimeline) {
                    TimelineView()
                }
                .libraryPanel(isPresented: $isShowingLibrary)
                .alert("Discard Unapplied Changes?", isPresented: $showDiscardChangesAlert) {
                    Button("Review Changes") {
                        isShowingTimeline = true
                    }
                    Button("Discard Changes", role: .destructive) {
                        projectManager.discardPendingChanges() // Use the dedicated discard function
                        syncManager.syncMode = .automatic
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Switching to Automatic Sync will discard all \(pendingChangesCount) pending changes in your timeline.")
                }
                .toolbar {
                    // (Picker | Timeline) — one combined item
                    ToolbarItem(placement: .primaryAction) {
                        syncPickerCluster()
                    }

                    // (Plus) — its own item
                    ToolbarItem(placement: .primaryAction) {
                        Button { isShowingLibrary.toggle() } label: {
                            Image(systemName: "plus")
                        }
                        .help("Add")
                    }

                    // (Feedback) — its own item
                    ToolbarItem(placement: .primaryAction) {
                        Button { showFeedbackSheet.toggle() } label: {
                            Image(systemName: "bubble.left.and.bubble.right")
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

    @ViewBuilder
    private func syncPickerCluster() -> some View {
        let isEcoMode = syncManager.syncMode == .manualECO
        let hasPendingChanges = !syncManager.pendingChanges.isEmpty

        HStack(spacing: 0) {
            Menu {
                 Picker("Sync Mode", selection: $projectManager.syncManager.syncMode) {
                     Label("Smart Sync", systemImage: "arrow.triangle.2.circlepath")
                         .tag(SyncMode.automatic)
                     Label("Manual ECO", systemImage: "list.bullet.clipboard")
                         .tag(SyncMode.manualECO)
                 }
                 .pickerStyle(.inline) // keeps it compact inside the menu
             } label: {
                 Image(systemName: "gearshape")
             }
             .help("Change Sync Mode")

            // Timeline button only in Manual ECO
            if isEcoMode {
                Button {
                    isShowingTimeline = true
                } label: {
                    Image(systemName: "text.and.command.macwindow")
                        .symbolRenderingMode(.hierarchical)
                        .if(hasPendingChanges) {
                            $0.badge(pendingChangesCount)
                        }
                }
                .help("Show Timeline (\(pendingChangesCount) Pending Changes)")
                .disabled(!hasPendingChanges)
            }
        }
        .animation(.snappy, value: isEcoMode)
    }
    
}
