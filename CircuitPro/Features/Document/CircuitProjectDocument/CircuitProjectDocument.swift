import SwiftUI
import UniformTypeIdentifiers

final class CircuitProjectDocument: NSDocument {

    // MARK: – Model
    var model = CircuitProject(name: "Untitled", designs: [])

    lazy var projectManager: ProjectManager = {
        return ProjectManager(project: model, modelContext: ModelContainerManager.shared.container.mainContext)
    }()

    override static var autosavesInPlace: Bool { true }

    // MARK: – Init
    override init() {
        super.init()
    }

    // MARK: – Window
    override func makeWindowControllers() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )

        window.center()
        window.title = "CircuitPro Project"
        window.toolbarStyle = .unifiedCompact

        let rootView = WorkspaceView(document: self)
            .modelContainer(ModelContainerManager.shared.container)
            .environment(\.projectManager, projectManager)

        window.contentView = NSHostingView(rootView: rootView)
        window.toolbar = NSToolbar(identifier: "CustomToolbar").apply {
            $0.displayMode = .iconOnly
            $0.allowsUserCustomization = false
        }

        addWindowController(NSWindowController(window: window))
    }

    // MARK: – Reading
    // 1.  URL-based reader (normal open/save cycle)
    override func read(from url: URL, ofType typeName: String) throws {

        // — project.json --------------------------------------------------
        let headerURL = url.appendingPathComponent("project.json")
        guard FileManager.default.fileExists(atPath: headerURL.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let headerData = try Data(contentsOf: headerURL)
        model = try JSONDecoder().decode(CircuitProject.self, from: headerData)

        // — components.json and wires.json of every design ----------------
        for index in model.designs.indices {
            let design = model.designs[index]
            let designDirURL = url
                .appendingPathComponent("Designs")
                .appendingPathComponent(design.directoryName)

            // Read components
            let compsURL = designDirURL.appendingPathComponent("components.json")
            if FileManager.default.fileExists(atPath: compsURL.path),
               let data = try? Data(contentsOf: compsURL),
               let instances = try? JSONDecoder().decode([ComponentInstance].self, from: data) {
                model.designs[index].componentInstances = instances
            }

            // Read wires
            let wiresURL = designDirURL.appendingPathComponent("wires.json")
            if FileManager.default.fileExists(atPath: wiresURL.path),
               let data = try? Data(contentsOf: wiresURL),
               let wires = try? JSONDecoder().decode([Wire].self, from: data) {
                model.designs[index].wires = wires
            }
        }
    }

    // 2.  FileWrapper-based reader (state restoration, hand-off, …)
    override func read(
        from fileWrapper: FileWrapper,
        ofType typeName: String
    ) throws {

        // — project.json
        guard
            let headerWrapper = fileWrapper.fileWrappers?["project.json"],
            let headerData    = headerWrapper.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        model = try JSONDecoder().decode(CircuitProject.self, from: headerData)

        // — components.json and wires.json of every design
        guard let designsDir = fileWrapper.fileWrappers?["Designs"] else { return }

        for index in model.designs.indices {
            let design = model.designs[index]
            guard let designDir = designsDir.fileWrappers?[design.directoryName] else { continue }

            // Read components
            if let compsWrapper = designDir.fileWrappers?["components.json"],
               let data = compsWrapper.regularFileContents,
               let instances = try? JSONDecoder().decode([ComponentInstance].self, from: data) {
                model.designs[index].componentInstances = instances
            }

            // Read wires
            if let wiresWrapper = designDir.fileWrappers?["wires.json"],
               let data = wiresWrapper.regularFileContents,
               let wires = try? JSONDecoder().decode([Wire].self, from: data) {
                model.designs[index].wires = wires
            }
        }
    }

    // MARK: – Writing
    //
    // Build an in-memory FileWrapper tree that represents the package
    // and let NSDocument write/replace it atomically.
    //
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {

        // Root directory of the *.circuitproj package
        let root = FileWrapper(directoryWithFileWrappers: [:])

        // 1. project.json  (the header / top-level model)
        let jsonData = try JSONEncoder().encode(model)
        let jsonFile = FileWrapper(regularFileWithContents: jsonData)
        jsonFile.preferredFilename = "project.json"
        root.addFileWrapper(jsonFile)

        // 2. Designs/
        let designsDir = FileWrapper(directoryWithFileWrappers: [:])
        designsDir.preferredFilename = "Designs"

        for design in model.designs {
            let designDir = FileWrapper(directoryWithFileWrappers: [:])
            designDir.preferredFilename = design.directoryName

            // 2.1 schematic.sch & layout.pcb stay unchanged
            designDir.addRegularFile(
                withContents: Data(),
                preferredFilename: "schematic.sch"
            )
            designDir.addRegularFile(
                withContents: Data(),
                preferredFilename: "layout.pcb"
            )

            // 2.2 Components data
            let compsData = try JSONEncoder().encode(design.componentInstances)
            designDir.addRegularFile(
                withContents: compsData,
                preferredFilename: "components.json"
            )

            // 2.3 Wires data
            let wiresData = try JSONEncoder().encode(design.wires)
            designDir.addRegularFile(
                withContents: wiresData,
                preferredFilename: "wires.json"
            )

            designsDir.addFileWrapper(designDir)
        }

        root.addFileWrapper(designsDir)
        return root
    }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [UTType.circuitProject.identifier]
    }
}

// Tiny helper
private extension NSToolbar {
    func apply(_ build: (NSToolbar) -> Void) -> NSToolbar { build(self); return self }
}
