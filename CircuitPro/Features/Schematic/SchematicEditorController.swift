import Observation
import SwiftDataPacks
import SwiftUI
import CoreGraphics

@MainActor
@Observable
final class SchematicEditorController {

    var selectedTool: CanvasTool = CursorTool()

    private let projectManager: ProjectManager
    private let document: CircuitProjectFileDocument
    var items: [any CanvasItem] {
        get {
            let design = projectManager.selectedDesign
            let pinPoints = symbolPinPoints(for: design.componentInstances)
            return design.componentInstances + pinPoints + design.wires.points + design.wires.links
        }
        set {
            let components = newValue.compactMap { $0 as? ComponentInstance }
            let wirePoints = newValue.compactMap { $0 as? WireVertex }
            let wireLinks = newValue.compactMap { $0 as? WireSegment }

            projectManager.selectedDesign.componentInstances = components
            projectManager.selectedDesign.wires = Wire(points: wirePoints, links: wireLinks)
            document.scheduleAutosave()
        }
    }

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document

    }

    private func symbolPinPoints(for components: [ComponentInstance]) -> [SymbolPinPoint] {
        var points: [SymbolPinPoint] = []
        for component in components {
            let symbol = component.symbolInstance
            guard let definition = symbol.definition else { continue }

            let rotation = symbol.rotation
            let transform = CGAffineTransform(rotationAngle: rotation)
            for pin in definition.pins {
                let rotated = pin.position.applying(transform)
                let position = CGPoint(x: symbol.position.x + rotated.x, y: symbol.position.y + rotated.y)
                points.append(SymbolPinPoint(symbolID: symbol.id, pinID: pin.id, position: position))
            }
        }
        return points
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
