// MARK: – Infrastructure/Document/CircuitProjectFile.swift

import SwiftUI
import UniformTypeIdentifiers

struct CircuitProjectFile: FileDocument {

    // MARK: - Properties
    var project: CircuitProject

    // MARK: - Initializers
    init() {
        self.project = CircuitProject(name: "Untitled", designs: [])
    }

    // MARK: - FileDocument Conformance
    static var readableContentTypes: [UTType] { [.circuitProject] }

    init(configuration: ReadConfiguration) throws {
        // (Your existing read implementation is correct and stays the same)
        guard let headerWrapper = configuration.file.fileWrappers?["project.json"],
              let headerData = headerWrapper.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var model = try JSONDecoder().decode(CircuitProject.self, from: headerData)
        if let designsDir = configuration.file.fileWrappers?["Designs"] {
            for index in model.designs.indices {
                let design = model.designs[index]
                guard let designDir = designsDir.fileWrappers?[design.directoryName] else { continue }
                if let compsWrapper = designDir.fileWrappers?["components.json"],
                   let data = compsWrapper.regularFileContents,
                   let instances = try? JSONDecoder().decode([ComponentInstance].self, from: data) {
                    model.designs[index].componentInstances = instances
                }
                if let wiresWrapper = designDir.fileWrappers?["wires.json"],
                   let data = wiresWrapper.regularFileContents,
                   let wires = try? JSONDecoder().decode([Wire].self, from: data) {
                    model.designs[index].wires = wires
                }
            }
        }
        self.project = model
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // (Your existing write implementation is correct and stays the same)
        let root = FileWrapper(directoryWithFileWrappers: [:])
        let jsonData = try JSONEncoder().encode(project)
        let jsonFile = FileWrapper(regularFileWithContents: jsonData)
        jsonFile.preferredFilename = "project.json"
        root.addFileWrapper(jsonFile)
        let designsDir = FileWrapper(directoryWithFileWrappers: [:])
        designsDir.preferredFilename = "Designs"
        for design in project.designs {
            let designDir = FileWrapper(directoryWithFileWrappers: [:])
            designDir.preferredFilename = design.directoryName
            let compsData = try JSONEncoder().encode(design.componentInstances)
            designDir.addRegularFile(withContents: compsData, preferredFilename: "components.json")
            let wiresData = try JSONEncoder().encode(design.wires)
            designDir.addRegularFile(withContents: wiresData, preferredFilename: "wires.json")
            designDir.addRegularFile(withContents: Data(), preferredFilename: "schematic.sch")
            designDir.addRegularFile(withContents: Data(), preferredFilename: "layout.pcb")
            designsDir.addFileWrapper(designDir)
        }
        root.addFileWrapper(designsDir)
        return root
    }
}

// MARK: - Document Data Mutations

extension CircuitProjectFile {
    /// This method now orchestrates the change on the `project` object.
    /// It no longer needs to be `mutating` because it's modifying the class instance,
    /// not the struct's properties directly.
    func addNewDesign(undoManager: UndoManager?) {
        let baseName = "Design"
        let existingIndices = project.designs.compactMap { design -> Int? in
            guard design.name.hasPrefix("\(baseName) ") else { return nil }
            return Int(design.name.dropFirst(baseName.count + 1))
        }
        let nextIndex = (existingIndices.max() ?? 0) + 1
        let newDesign = CircuitDesign(name: "\(baseName) \(nextIndex)")
        let insertionIndex = self.project.designs.count

        // Perform the action
        self.project.designs.append(newDesign)
        
        // Register the undo operation with the `project` class as the target.
        undoManager?.registerUndo(withTarget: self.project) { targetProject in
            // This closure is executed when the user Undos.
            // `targetProject` is the `self.project` object.
            
            // Remove the design that was added.
            targetProject.designs.remove(at: insertionIndex)
            
            // IMPORTANT: An undo action must register its corresponding redo action.
            // The redo action is to add the design back.
            undoManager?.registerUndo(withTarget: targetProject) { redoTarget in
                redoTarget.designs.insert(newDesign, at: insertionIndex)
            }
            undoManager?.setActionName("Add Design")
        }
        undoManager?.setActionName("Add Design")
    }

    /// Deletes a design from the project and registers an undo action.
    /// This method also no longer needs to be `mutating`.
    func deleteDesign(_ design: CircuitDesign, undoManager: UndoManager?) {
        guard let index = project.designs.firstIndex(where: { $0.id == design.id }) else { return }
        
        // Store the design we are about to remove so we can restore it for undo.
        let removedDesign = project.designs[index]

        // Perform the deletion
        project.designs.remove(at: index)
        
        // Register the undo operation with the `project` class as the target.
        undoManager?.registerUndo(withTarget: self.project) { targetProject in
            // This is the undo action: insert the removed design back.
            targetProject.designs.insert(removedDesign, at: index)
            
            // Register the redo action: delete the design again.
            undoManager?.registerUndo(withTarget: targetProject) { redoTarget in
                redoTarget.designs.remove(at: index)
            }
            undoManager?.setActionName("Delete Design")
        }
        undoManager?.setActionName("Delete Design")
    }
}
