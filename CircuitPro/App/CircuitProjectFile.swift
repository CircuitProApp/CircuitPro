// MARK: – Infrastructure/Document/CircuitProjectFile.swift

import SwiftUI
import UniformTypeIdentifiers

// Note: This assumes you have a UTType defined for your project file,
// for example, in an `UTType+Extensions.swift` file.
//
// extension UTType {
//     static var circuitProject: UTType {
//         UTType(exportedAs: "com.yourcompany.circuitpro.circuitproj")
//     }
// }

struct CircuitProjectFile: FileDocument {

    // MARK: - Properties

    /// The core data model for the entire document.
    /// All changes to your project's data will happen on this property.
    var project: CircuitProject

    // MARK: - Initializers

    /// Creates an empty document for a new, untitled project.
    /// This is called when the user selects "File > New".
    init() {
        self.project = CircuitProject(name: "Untitled", designs: [])
    }

    // MARK: - FileDocument Conformance

    /// Specifies the file types this document can read. The system uses this to
    /// know which files to show in the "Open" dialog.
    static var readableContentTypes: [UTType] { [.circuitProject] }

    /// Initializes a document by reading data from a file package.
    /// This is called when the user opens an existing `.circuitproj` file.
    init(configuration: ReadConfiguration) throws {
        // Find the main `project.json` file inside the `.circuitproj` package.
        guard let headerWrapper = configuration.file.fileWrappers?["project.json"],
              let headerData = headerWrapper.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // First, decode the main project structure (name and list of designs).
        var model = try JSONDecoder().decode(CircuitProject.self, from: headerData)

        // If a "Designs" subfolder exists, iterate through it to load detailed data.
        if let designsDir = configuration.file.fileWrappers?["Designs"] {
            for index in model.designs.indices {
                let design = model.designs[index]
                
                // Find the specific directory for this design using its unique ID as the folder name.
                guard let designDir = designsDir.fileWrappers?[design.directoryName] else { continue }
                
                // Read the components data from `components.json` if it exists.
                if let compsWrapper = designDir.fileWrappers?["components.json"],
                   let data = compsWrapper.regularFileContents,
                   let instances = try? JSONDecoder().decode([ComponentInstance].self, from: data) {
                    model.designs[index].componentInstances = instances
                }

                // Read the wires data from `wires.json` if it exists.
                if let wiresWrapper = designDir.fileWrappers?["wires.json"],
                   let data = wiresWrapper.regularFileContents,
                   let wires = try? JSONDecoder().decode([Wire].self, from: data) {
                    model.designs[index].wires = wires
                }
            }
        }
        
        // Assign the fully loaded model to the document's central `project` property.
        self.project = model
    }

    /// Creates a file package (a directory with files inside) to save the document's data.
    /// This is called whenever the system needs to write the document to disk (Save, Auto-Save, etc.).
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Create the root directory file wrapper for the .circuitproj package.
        let root = FileWrapper(directoryWithFileWrappers: [:])

        // 1. Encode the main project model and save it as `project.json`.
        let jsonData = try JSONEncoder().encode(project)
        let jsonFile = FileWrapper(regularFileWithContents: jsonData)
        jsonFile.preferredFilename = "project.json"
        root.addFileWrapper(jsonFile)

        // 2. Create the `Designs/` subdirectory to hold all design-specific data.
        let designsDir = FileWrapper(directoryWithFileWrappers: [:])
        designsDir.preferredFilename = "Designs"

        for design in project.designs {
            // For each design, create its own subdirectory named with its unique ID.
            let designDir = FileWrapper(directoryWithFileWrappers: [:])
            designDir.preferredFilename = design.directoryName

            // 2a. Write the components to `components.json`.
            let compsData = try JSONEncoder().encode(design.componentInstances)
            designDir.addRegularFile(withContents: compsData, preferredFilename: "components.json")

            // 2b. Write the wires to `wires.json`.
            let wiresData = try JSONEncoder().encode(design.wires)
            designDir.addRegularFile(withContents: wiresData, preferredFilename: "wires.json")
            
            // 2c. Add placeholder files to match your original document structure.
            designDir.addRegularFile(withContents: Data(), preferredFilename: "schematic.sch")
            designDir.addRegularFile(withContents: Data(), preferredFilename: "layout.pcb")

            // Add the populated design directory (e.g., ".../A4B8E...") to the main "Designs" directory.
            designsDir.addFileWrapper(designDir)
        }

        // Add the fully populated "Designs" directory to the root of the package.
        root.addFileWrapper(designsDir)
        return root
    }
}

// MARK: - Document Data Mutations

extension CircuitProjectFile {

    /// Adds a new design to the project and registers an undo action.
    /// - Parameter undoManager: The undo manager from the SwiftUI environment used to register the action.
    mutating func addNewDesign(undoManager: UndoManager?) {
        let baseName = "Design"
        
        // Find the highest existing number in names like "Design 1", "Design 2", etc., to avoid collisions.
        let existingIndices = project.designs.compactMap { design -> Int? in
            guard design.name.hasPrefix("\(baseName) ") else { return nil }
            return Int(design.name.dropFirst(baseName.count + 1))
        }
        
        let nextIndex = (existingIndices.max() ?? 0) + 1
        let newDesign = CircuitDesign(name: "\(baseName) \(nextIndex)")
        
        // To support undo, we specify how to reverse the action *before* we perform it.
        let insertionIndex = self.project.designs.count
        undoManager?.registerUndo(withTarget: self) { doc in
            // The reverse of adding is removing the item at the same index.
            doc.project.designs.remove(at: insertionIndex)
            undoManager?.setActionName("Add Design")
        }
        
        // Now, perform the action.
        self.project.designs.append(newDesign)
    }

    /// Deletes a design from the project and registers an undo action.
    /// - Parameters:
    ///   - design: The design object to delete.
    ///   - undoManager: The undo manager from the SwiftUI environment.
    mutating func deleteDesign(_ design: CircuitDesign, undoManager: UndoManager?) {
        guard let index = project.designs.firstIndex(where: { $0.id == design.id }) else { return }
        
        // Store the design we are about to remove so we can restore it for undo.
        let removedDesign = project.designs[index]

        // Register the undo action before making the change.
        undoManager?.registerUndo(withTarget: self) { doc in
            // The reverse of deleting is inserting the same item back at its original index.
            doc.project.designs.insert(removedDesign, at: index)
            undoManager?.setActionName("Delete Design")
        }
        
        // Perform the deletion.
        project.designs.remove(at: index)
    }
}