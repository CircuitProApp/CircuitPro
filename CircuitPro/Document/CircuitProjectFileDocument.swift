//
//  CircuitProjectFileDocument.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

@Observable
@MainActor
final class CircuitProjectFileDocument: ReferenceFileDocument {
    typealias Snapshot = CircuitProject

    static var readableContentTypes: [UTType] { [.circuitProject] }

    let syncManager = SyncManager()

    private var autosaveWorkItem: DispatchWorkItem?
    private var autosavePending = false
    var autosaveDelay: TimeInterval = 2

    func scheduleAutosave() {
        if autosaveWorkItem != nil {
            autosavePending = true
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.autosaveWorkItem = nil

            guard let url = self.fileURL else { return }
            do {
                try self.write(to: url)
                print("AUTOSAVE")
            } catch {
                // Non-blocking error handling; consider a banner/toast instead of an alert.
                NSLog("Autosave failed: \(error.localizedDescription)")
            }

            if self.autosavePending {
                self.autosavePending = false
                self.scheduleAutosave()
            }
        }

        autosaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay, execute: work)
    }

    var model: CircuitProject {
        didSet {
            scheduleAutosave()
        }
    }
    // Track the backing URL when opened/saved programmatically
    var fileURL: URL?

    // Programmatic initializers (not used by DocumentGroup)
    init(newWithName name: String) {
        self.model = CircuitProject(name: name, designs: [CircuitDesign(name: "Design 1")])
    }

    convenience init(fileURL url: URL, container: ModelContainer) throws {
        let wrapper = try FileWrapper(url: url, options: .immediate)
        var model = try Self.readPackage(from: wrapper)
        try model.hydrate(using: container)
        self.init(model: model, fileURL: url)
    }

    private init(model: CircuitProject, fileURL: URL?) {
        self.model = model
        self.fileURL = fileURL
    }

    // Required by ReferenceFileDocument (used if you ever adopt DocumentGroup)
    required init(configuration: ReadConfiguration) throws {
        self.model = try Self.readPackage(from: configuration.file)
        self.fileURL = nil
    }

    func snapshot(contentType: UTType) throws -> CircuitProject {
        model
    }

    func fileWrapper(snapshot: CircuitProject, configuration: WriteConfiguration) throws -> FileWrapper {
        try Self.buildPackage(from: snapshot)
    }

    // Programmatic save (no DocumentGroup)
    func write(to url: URL) throws {
        let wrapper = try Self.buildPackage(from: model)
        // Create parent dir if needed
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try wrapper.write(to: url, options: .atomic, originalContentsURL: fileURL)
        fileURL = url
    }
}

// MARK: - Package IO helpers
private extension CircuitProjectFileDocument {
    enum Layout {
        static let header = "project.json"
        static let designsDir = "Designs"
        static let components = "components.json"
        static let wires = "wires.json"
        static let traces = "traces.json"
    }

    static func buildPackage(from project: CircuitProject) throws -> FileWrapper {
        let root = FileWrapper(directoryWithFileWrappers: [:])

        // Header
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let headerData = try enc.encode(project)
        let headerFile = FileWrapper(regularFileWithContents: headerData)
        headerFile.preferredFilename = Layout.header
        root.addFileWrapper(headerFile)

        // Designs/
        let designsDir = FileWrapper(directoryWithFileWrappers: [:])
        designsDir.preferredFilename = Layout.designsDir

        for design in project.designs {
            let designDir = FileWrapper(directoryWithFileWrappers: [:])
            designDir.preferredFilename = design.directoryName

            // Components
            let compsData = try enc.encode(design.componentInstances)
            designDir.addRegularFile(withContents: compsData, preferredFilename: Layout.components)

            // Wires
            let wiresData = try enc.encode(design.wires)
            designDir.addRegularFile(withContents: wiresData, preferredFilename: Layout.wires)

            // Traces
            let tracesData = try enc.encode(design.traces)
            designDir.addRegularFile(withContents: tracesData, preferredFilename: Layout.traces)

            designsDir.addFileWrapper(designDir)
        }

        root.addFileWrapper(designsDir)
        return root
    }

    static func readPackage(from fileWrapper: FileWrapper) throws -> CircuitProject {
        guard let header = fileWrapper.fileWrappers?[Layout.header],
              let data = header.regularFileContents
        else { throw CocoaError(.fileReadCorruptFile) }

        var project = try JSONDecoder().decode(CircuitProject.self, from: data)

        guard let designsDir = fileWrapper.fileWrappers?[Layout.designsDir] else {
            return project
        }

        for index in project.designs.indices {
            let design = project.designs[index]
            guard let designDir = designsDir.fileWrappers?[design.directoryName] else { continue }

            if let comps = designDir.fileWrappers?[Layout.components]?.regularFileContents,
               let instances = try? JSONDecoder().decode([ComponentInstance].self, from: comps) {
                project.designs[index].componentInstances = instances
            }

            if let wires = designDir.fileWrappers?[Layout.wires]?.regularFileContents,
               let wireData = try? JSONDecoder().decode(Wire.self, from: wires) {
                project.designs[index].wires = wireData
            }

            if let traces = designDir.fileWrappers?[Layout.traces]?.regularFileContents,
               let traceData = try? JSONDecoder().decode(Trace.self, from: traces) {
                project.designs[index].traces = traceData
            }
        }

        return project
    }
}
