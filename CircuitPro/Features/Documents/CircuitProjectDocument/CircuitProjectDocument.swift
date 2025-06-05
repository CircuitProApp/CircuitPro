import SwiftUI
import UniformTypeIdentifiers

//──────────────  CircuitProjectDocument  ──────────────
final class CircuitProjectDocument: NSDocument {

    // MARK: – Model ---------------------------------------------------
    var model = CircuitProject(name: "Untitled", designs: [])

    override class var autosavesInPlace: Bool { true }

    // MARK: – Init ----------------------------------------------------
    override init() {
        super.init()
    }

    // MARK: – Window --------------------------------------------------
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

        window.contentView = NSHostingView(rootView: rootView)
        window.toolbar = NSToolbar(identifier: "CustomToolbar").apply {
            $0.displayMode = .iconOnly
            $0.allowsUserCustomization = false
        }

        addWindowController(NSWindowController(window: window))
    }

    // MARK: – Reading -------------------------------------------------
    //
    // The project package arrives as a FileWrapper tree.  We only need
    // the JSON file that contains the model.
    //
    override func read(from url: URL, ofType typeName: String) throws {
        let jsonURL = url.appendingPathComponent("project.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let data = try Data(contentsOf: jsonURL)
        model = try JSONDecoder().decode(CircuitProject.self, from: data)
    }

    // 2. When the document is restored by state-restoration the system
    //    may pass a FileWrapper instead.  Keep the wrapper-based reader
    //    as well (harmless duplication).
    override func read(from fileWrapper: FileWrapper,
                       ofType typeName: String) throws {

        guard
            let jsonWrapper = fileWrapper.fileWrappers?["project.json"],
            let jsonData    = jsonWrapper.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        model = try JSONDecoder().decode(CircuitProject.self, from: jsonData)
    }

    // MARK: – Writing -------------------------------------------------
    //
    // Build an in-memory FileWrapper tree that represents the package
    // and let NSDocument write/replace it atomically.
    //
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {

        // Always make sure we have at least one design
        if model.designs.isEmpty {
            model.designs = [CircuitDesign(name: "Design 1",
                                           folderPath: "Design 1")]
        }

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
            designDir.preferredFilename = design.folderPath

            // empty placeholders – replace with real contents if/when you have them
            designDir.addRegularFile(withContents: Data(),
                                     preferredFilename: "schematic.sch")
            designDir.addRegularFile(withContents: Data(),
                                     preferredFilename: "layout.pcb")
            let componentsJSON = try JSONSerialization.data(withJSONObject: [])
            designDir.addRegularFile(withContents: componentsJSON,
                                     preferredFilename: "components.json")

            designsDir.addFileWrapper(designDir)
        }

        root.addFileWrapper(designsDir)
        return root
    }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [UTType.circuitProject.identifier]
    }


    // MARK: – Editing helpers ----------------------------------------
    //
    // These now only mutate the *model*; the actual directories are
    // created on the next save by `fileWrapper(ofType:)`.
    //
    func addNewDesign() {
        let base = "Design"
        var idx  = model.designs.count + 1
        var name = "\(base) \(idx)"

        let used = Set(model.designs.map(\.name))
        while used.contains(name) {
            idx += 1
            name = "\(base) \(idx)"
        }

        model.designs.append(.init(name: name, folderPath: name))
        updateChangeCount(.changeDone)
    }

    func renameDesign(_ design: CircuitDesign, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != design.folderPath else { return }

        design.folderPath = trimmed
        design.name       = trimmed       // keep model consistent
        updateChangeCount(.changeDone)
    }
}


//──────────────  Tiny helper  ──────────────
private extension NSToolbar {
    func apply(_ build: (NSToolbar) -> Void) -> NSToolbar { build(self); return self }
}
