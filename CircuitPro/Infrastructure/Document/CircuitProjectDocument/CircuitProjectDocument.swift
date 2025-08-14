import SwiftUI
import UniformTypeIdentifiers
import AppKit
import WelcomeWindow

final class CircuitProjectDocument: NSDocument {

    // MARK: – Model
    var model = CircuitProject(name: "Untitled", designs: [])

    lazy var projectManager: ProjectManager = {
        ProjectManager(project: model, modelContext: ModelContainerManager.shared.container.mainContext)
    }()

    override static var autosavesInPlace: Bool { true }

    // Important: SwiftUI will own the windows. Do not create NSWindow here.
    override func makeWindowControllers() {
        // Intentionally empty
    }

    // MARK: – Reading (kept as-is)
    override func read(from url: URL, ofType typeName: String) throws {
        // ... your existing URL-based reader ...
        let headerURL = url.appendingPathComponent("project.json")
        guard FileManager.default.fileExists(atPath: headerURL.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let headerData = try Data(contentsOf: headerURL)
        model = try JSONDecoder().decode(CircuitProject.self, from: headerData)

        for index in model.designs.indices {
            let design = model.designs[index]
            let designDirURL = url
                .appendingPathComponent("Designs")
                .appendingPathComponent(design.directoryName)

            let compsURL = designDirURL.appendingPathComponent("components.json")
            if FileManager.default.fileExists(atPath: compsURL.path),
               let data = try? Data(contentsOf: compsURL),
               let instances = try? JSONDecoder().decode([ComponentInstance].self, from: data) {
                model.designs[index].componentInstances = instances
            }

            let wiresURL = designDirURL.appendingPathComponent("wires.json")
            if FileManager.default.fileExists(atPath: wiresURL.path),
               let data = try? Data(contentsOf: wiresURL),
               let wires = try? JSONDecoder().decode([Wire].self, from: data) {
                model.designs[index].wires = wires
            }
        }
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        // ... your existing FileWrapper-based reader ...
        guard
            let headerWrapper = fileWrapper.fileWrappers?["project.json"],
            let headerData    = headerWrapper.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        model = try JSONDecoder().decode(CircuitProject.self, from: headerData)

        guard let designsDir = fileWrapper.fileWrappers?["Designs"] else { return }

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

    // MARK: – Writing
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        // ... your existing package writer ...
        let root = FileWrapper(directoryWithFileWrappers: [:])

        let jsonData = try JSONEncoder().encode(model)
        let jsonFile = FileWrapper(regularFileWithContents: jsonData)
        jsonFile.preferredFilename = "project.json"
        root.addFileWrapper(jsonFile)

        let designsDir = FileWrapper(directoryWithFileWrappers: [:])
        designsDir.preferredFilename = "Designs"

        for design in model.designs {
            let designDir = FileWrapper(directoryWithFileWrappers: [:])
            designDir.preferredFilename = design.directoryName

            designDir.addRegularFile(withContents: Data(), preferredFilename: "schematic.sch")
            designDir.addRegularFile(withContents: Data(), preferredFilename: "layout.pcb")

            let compsData = try JSONEncoder().encode(design.componentInstances)
            designDir.addRegularFile(withContents: compsData, preferredFilename: "components.json")

            let wiresData = try JSONEncoder().encode(design.wires)
            designDir.addRegularFile(withContents: wiresData, preferredFilename: "wires.json")

            designsDir.addFileWrapper(designDir)
        }

        root.addFileWrapper(designsDir)
        return root
    }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [UTType.circuitProject.identifier]
    }
}

import AppKit
import UniformTypeIdentifiers

extension NSDocumentController {

    @MainActor
    func createFileDocumentWithDialog(
        configuration: DocumentSaveDialogConfiguration = .init(),
        onDialogPresented: @escaping () -> Void = {},
        onCompletion: @escaping (_ id: DocumentID) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        _createDocument(
            mode: .file,
            configuration: configuration,
            onDialogPresented: onDialogPresented,
            onCompletion: onCompletion,
            onCancel: onCancel
        )
    }

    @MainActor
    func createFolderDocumentWithDialog(
        configuration: DocumentSaveDialogConfiguration,
        onDialogPresented: @escaping () -> Void = {},
        onCompletion: @escaping (_ id: DocumentID) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        _createDocument(
            mode: .folder,
            configuration: configuration,
            onDialogPresented: onDialogPresented,
            onCompletion: onCompletion,
            onCancel: onCancel
        )
    }

    private enum SaveMode { case file, folder }

    private func configureSavePanel(mode: SaveMode, configuration: DocumentSaveDialogConfiguration) -> NSSavePanel {
        let panel = NSSavePanel()
        panel.prompt = configuration.prompt
        panel.title = configuration.title
        panel.nameFieldLabel = configuration.nameFieldLabel
        panel.canCreateDirectories = true
        panel.directoryURL = configuration.directoryURL
        panel.level = .modalPanel
        panel.treatsFilePackagesAsDirectories = true

        switch mode {
        case .file:
            panel.nameFieldStringValue = configuration.defaultFileName
            panel.allowedContentTypes  = configuration.allowedContentTypes
        case .folder:
            panel.nameFieldStringValue =
                URL(fileURLWithPath: configuration.defaultFileName)
                    .deletingPathExtension()
                    .lastPathComponent
            panel.allowedContentTypes  = [] // treat as plain folder
        }

        return panel
    }

    @MainActor
    private func _createDocument(
        mode: SaveMode,
        configuration: DocumentSaveDialogConfiguration,
        onDialogPresented: @escaping () -> Void,
        onCompletion: @escaping (_ id: DocumentID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let panel = configureSavePanel(mode: mode, configuration: configuration)

        DispatchQueue.main.async { onDialogPresented() }

        guard panel.runModal() == .OK, let baseURL = panel.url else {
            onCancel()
            return
        }

        do {
            if mode == .folder {
                try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
            }

            let ext = configuration.defaultFileType.preferredFilenameExtension ?? "file"

            let finalURL = if mode == .folder {
                baseURL.appendingPathComponent("\(baseURL.lastPathComponent).\(ext)")
            } else {
                baseURL
            }

            // Create a temporary untitled document to produce initial contents on disk.
            let tempDoc = try makeUntitledDocument(ofType: configuration.defaultFileType.identifier)
            tempDoc.fileURL = finalURL
            try tempDoc.write(
                to: finalURL,
                ofType: configuration.defaultFileType.identifier,
                for: .saveOperation,
                originalContentsURL: nil
            )

            // Now open the real managed document instance with display: false
            openDocument(at: finalURL, display: false, onCompletion: onCompletion, onError: { error in
                NSAlert(error: error).runModal()
                onCancel()
            })
        } catch {
            NSAlert(error: error).runModal()
            onCancel()
        }
    }

    @MainActor
    func openDocumentWithDialog(
        configuration: DocumentOpenDialogConfiguration = .init(),
        onDialogPresented: @escaping () -> Void = {},
        onCompletion: @escaping (_ id: DocumentID) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        let panel = NSOpenPanel()
        panel.title = configuration.title
        panel.canChooseFiles = configuration.canChooseFiles
        panel.canChooseDirectories = configuration.canChooseDirectories
        panel.allowedContentTypes = configuration.allowedContentTypes
        panel.directoryURL = configuration.directoryURL
        panel.level = .modalPanel

        panel.begin { result in
            guard result == .OK, let selectedURL = panel.url else {
                onCancel()
                return
            }

            self.openDocument(at: selectedURL, display: false, onCompletion: onCompletion, onError: { _ in onCancel() })
        }
        onDialogPresented()
    }

    @MainActor
    func openDocument(
        at url: URL,
        display: Bool = false,
        onCompletion: @escaping (_ id: DocumentID) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        let accessGranted = RecentsStore.beginAccessing(url)
        openDocument(withContentsOf: url, display: display) { doc, _, error in
            if let error {
                if accessGranted { RecentsStore.endAccessing(url) }
                DispatchQueue.main.async { NSAlert(error: error).runModal() }
                onError(error)
            } else if let doc = doc as? CircuitProjectDocument {
                RecentsStore.documentOpened(at: url)
                DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
                let id = DocumentRegistry.shared.register(doc, url: url)
                onCompletion(id)
            } else {
                if accessGranted { RecentsStore.endAccessing(url) }
                onError(CocoaError(.fileReadUnknown))
            }
        }
    }
}
