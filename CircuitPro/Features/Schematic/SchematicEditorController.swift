import Observation
import SwiftDataPacks
import SwiftUI

@MainActor
@Observable
final class SchematicEditorController {

    var selectedTool: CanvasTool = CursorTool()

    private let projectManager: ProjectManager
    private let document: CircuitProjectFileDocument
    var items: [any CanvasItem] {
        get { projectManager.selectedDesign.componentInstances }
        set {
            projectManager.selectedDesign.componentInstances = newValue.compactMap {
                $0 as? ComponentInstance
            }
            document.scheduleAutosave()
        }
    }

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document

    }

    // MARK: - Public Actions

    /// Handles dropping a new component onto the canvas from a library.
    /// This logic was moved from SchematicCanvasView.
    func handleComponentDrop(
        from transferable: TransferableComponent,
        at location: CGPoint,
        packManager: SwiftDataPackManager
    ) -> UUID? {
        var fetchDescriptor = FetchDescriptor<ComponentDefinition>(
            predicate: #Predicate { $0.uuid == transferable.componentUUID })
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.symbol]
        let fullLibraryContext = ModelContext(packManager.mainContainer)

        guard let componentDefinition = (try? fullLibraryContext.fetch(fetchDescriptor))?.first,
            let symbolDefinition = componentDefinition.symbol
        else {
            return nil
        }

        // 1. THE FIX for SymbolInstance
        // We now correctly pass the `definitionUUID` from the symbol's definition.
        let newSymbolInstance = SymbolInstance(
            definitionUUID: symbolDefinition.uuid,
            definition: symbolDefinition,
            position: location
        )

        // 2. THE FIX for ComponentInstance
        // We now correctly pass the `definitionUUID` from the component's definition
        // and the `symbolInstance` we just created.
        let newComponentInstance = ComponentInstance(
            definitionUUID: componentDefinition.uuid,
            definition: componentDefinition,
            symbolInstance: newSymbolInstance
        )

        // This part is already correct. We just mutate the model.
        projectManager.componentInstances.append(newComponentInstance)

        // The @Observable chain will automatically handle the rest.
        projectManager.document.scheduleAutosave()
        return newComponentInstance.id
    }

}
