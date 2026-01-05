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

    @BindableEnvironment(\.editorSession)
    private var editorSession

    private var syncManager: SyncManager {
        projectManager.syncManager
    }

    @State private var showInspector: Bool = false
    @State private var isShowingLibrary: Bool = false
    @State private var isShowingTimeline: Bool = false
    @State private var showDiscardChangesAlert: Bool = false

    // Count UNIQUE fields being edited, not total history records
    private var pendingFieldEditsCount: Int {
        uniqueFieldKeys(syncManager.pendingChanges).count
    }

    private var pendingChangesCountBadge: String {
        let count = pendingFieldEditsCount
        return count > 99 ? "99+" : "\(count)"
    }

    private var hasPendingFieldEdits: Bool {
        pendingFieldEditsCount > 0
    }

    // Builds a set of unique "field keys" across all pending records:
    // - RefDes per component
    // - Footprint per component
    // - Property per (component, propertyID)
    private func uniqueFieldKeys(_ changes: [ChangeRecord]) -> Set<String> {
        var keys: Set<String> = []
        for r in changes {
            switch r.payload {
            case .updateReferenceDesignator(let cid, _, _):
                keys.insert("refdes:\(cid.uuidString)")
            case .assignFootprint(let cid, _, _, _):
                keys.insert("footprint:\(cid.uuidString)")
            case .updateProperty(let cid, let newProp, _):
                keys.insert("prop:\(cid.uuidString):\(newProp.id.uuidString)")
            }
        }
        return keys
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
        NavigationSplitView {
            NavigatorView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 320)
        } detail: {
            EditorView()
                
                .frame(minWidth: 320)
              
                .sheet(isPresented: $isShowingTimeline) {
                    TimelineView()
                }
                .libraryPanel(isPresented: $isShowingLibrary)
                .alert("Discard Unapplied Changes?", isPresented: $showDiscardChangesAlert) {
                    Button("Review Changes") {
                        isShowingTimeline = true
                    }
                    Button("Discard Changes", role: .destructive) {
                        projectManager.discardPendingChanges()
                        syncManager.syncMode = .automatic
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Switching to Automatic Sync will discard all \(pendingChangesCountBadge) pending field edits in your timeline.")
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        editorPicker()
                    }
                    ToolbarItem(placement: .primaryAction) {
                        syncPickerCluster()
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { isShowingLibrary.toggle() } label: {
                            Image(systemName: "plus")
                        }
                        .help("Add")
                    }
                }
        }
        .frame(minHeight: 400)
        .inspector(isPresented: $showInspector) {
            InspectorView()
//                .inspectorColumnWidth(ideal: 300)
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
    }

    @ViewBuilder
    private func editorPicker() -> some View {
        Picker("Editor", selection: $editorSession.selectedEditor) {
            Text("Schematic")
                .tag(EditorType.schematic)
            Text("Layout")
                .tag(EditorType.layout)
        }
        .pickerStyle(.segmented)
        .help("Switch Editor")
    }

    @ViewBuilder
    private func syncPickerCluster() -> some View {
        let isEcoMode = syncManager.syncMode == .manualECO

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
                        .if(hasPendingFieldEdits) {
                            $0.badge(pendingChangesCountBadge)
                        }
                }
                .help("Show Timeline (\(pendingChangesCountBadge) Pending Field Edits)")
                .disabled(!hasPendingFieldEdits)
            }
        }
        .animation(.snappy, value: isEcoMode)
    }
}
