//
//  CircuitProjectFileDocument.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI
import UniformTypeIdentifiers

final class CircuitProjectFileDocument: ReferenceFileDocument {
    typealias Snapshot = CircuitProject

    static var readableContentTypes: [UTType] { [.circuitProject] }

    @Published var model: CircuitProject
    // Track the backing URL when opened/saved programmatically
    var fileURL: URL?

    // Programmatic initializers (not used by DocumentGroup)
    init(newWithName name: String) {
        self.model = CircuitProject(name: name, designs: [])
    }

    convenience init(fileURL url: URL) throws {
        let wrapper = try FileWrapper(url: url, options: .immediate)
        let model = try Self.readPackage(from: wrapper)
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
        static let schematic = "schematic.sch"
        static let layout = "layout.pcb"
        static let components = "components.json"
        static let wires = "wires.json"
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

            // Placeholders for raw files
            designDir.addRegularFile(withContents: Data(), preferredFilename: Layout.schematic)
            designDir.addRegularFile(withContents: Data(), preferredFilename: Layout.layout)

            // Components
            let compsData = try enc.encode(design.componentInstances)
            designDir.addRegularFile(withContents: compsData, preferredFilename: Layout.components)

            // Wires
            let wiresData = try enc.encode(design.wires)
            designDir.addRegularFile(withContents: wiresData, preferredFilename: Layout.wires)

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
               let wiresArr = try? JSONDecoder().decode([Wire].self, from: wires) {
                project.designs[index].wires = wiresArr
            }
        }

        return project
    }
}
