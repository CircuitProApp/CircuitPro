// Features/Editor/SchematicEditorController.swift (Corrected)

import SwiftUI
import Observation

@MainActor
@Observable
final class SchematicEditorController: EditorController {
    
    private(set) var nodes: [BaseNode] = []
    
    private let projectManager: ProjectManager
    private let document: CircuitProjectFileDocument
    private let nodeProvider: SchematicNodeProvider
    
    // MODIFICATION 1: Made internal (by removing `private`) so other views can access it.
    let schematicGraph: WireGraph

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.schematicGraph = WireGraph()
        self.nodeProvider = SchematicNodeProvider(
            projectManager: projectManager,
            schematicGraph: self.schematicGraph
        )
        self.schematicGraph.onModelDidChange = { [weak self] in
            self?.persistGraph()
        }
        startTrackingModelChanges()
        
        Task {
                await self.rebuildNodes()
            }
    }

    private func startTrackingModelChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
            _ = projectManager.syncManager.pendingChanges
        } onChange: {
            Task { @MainActor in
                // MODIFICATION 2: We now `await` the async rebuild function.
                await self.rebuildNodes()
                
                // The recursive call must happen *after* the await is complete.
                self.startTrackingModelChanges()
            }
        }
    }
    
    // MODIFICATION 2: Marked the function as `async`.
    private func rebuildNodes() async {
        guard let design = projectManager.selectedDesign else {
            self.nodes = []
            return
        }
        
        let context = BuildContext(activeLayers: [])
        
        // The `Task { }` wrapper is removed. We just `await` the call directly.
        self.nodes = await nodeProvider.buildNodes(from: design, context: context)
    }
    
    func findNode(with id: UUID) -> BaseNode? {
        return nodes.findNode(with: id)
    }
    
    private func persistGraph() {
        guard let design = projectManager.selectedDesign else { return }
        design.wires = schematicGraph.toWires()
        document.scheduleAutosave()
    }
}
