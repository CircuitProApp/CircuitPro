//
//  WorkspaceView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/1/25.
//

import SwiftUI
import SwiftData

struct WorkspaceView: View {
    
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
    
    private var syncModeBinding: Binding<SyncMode> {
        Binding(
            get: { self.syncManager.syncMode },
            set: { newMode in
                if newMode == .automatic && !syncManager.pendingChanges.isEmpty {
                    self.showDiscardChangesAlert = true
                } else {
                    self.syncManager.syncMode = newMode
                }
            }
        )
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
                // --- CORRECTED ALERT STRUCTURE ---
                .alert("Discard Unapplied Changes?", isPresented: $showDiscardChangesAlert) {
                    // 1. "Review Changes" is the default action (no role = blue).
                    Button("Review Changes") {
                        isShowingTimeline = true
                    }
                    
                    // 2. "Discard Changes" is the destructive action.
                    Button("Discard Changes", role: .destructive) {
                        projectManager.discardPendingChanges()
                        syncManager.syncMode = .automatic
                    }
                    
                    // 3. "Cancel" is the explicit cancel action.
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
                 Picker("Sync Mode", selection: syncModeBinding) {
                     Label("Smart Sync", systemImage: "arrow.triangle.2.circlepath")
                         .tag(SyncMode.automatic)
                     Label("Manual ECO", systemImage: "pencil.and.list.clipboard")
                         .tag(SyncMode.manualECO)
                 }
                 .pickerStyle(.inline)
             } label: {
                 Image(systemName: "gearshape.arrow.trianglehead.2.clockwise.rotate.90")
             }
             .help("Change Sync Mode")

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
