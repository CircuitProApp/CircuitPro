import Cocoa
import UniformTypeIdentifiers

final class CircuitProjectDocumentController: NSDocumentController {

    override func newDocument(_ sender: Any?) {
        print("✅ CircuitProjectDocumentController.newDocument called")

        let panel = NSSavePanel()
        panel.prompt = "Create Project"
        panel.nameFieldLabel = "Project Name:"
        panel.nameFieldStringValue = "NewCircuitProject"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = []
        panel.title = "Create a New Circuit Pro Project"
        panel.level = .modalPanel
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        panel.begin { response in
            guard response == .OK, let projectFolderURL = panel.url else { return }

            let projectName = projectFolderURL.lastPathComponent
            let descriptorURL = projectFolderURL.appendingPathComponent("\(projectName).circuitproj")

            do {
                try FileManager.default.createDirectory(at: projectFolderURL, withIntermediateDirectories: true)
                let model = CircuitProjectModel(name: projectName, version: "1.0")
                let data = try JSONEncoder().encode(model)
                try data.write(to: descriptorURL)

                for subdir in ["Schematic", "Board"] {
                    let subfolder = projectFolderURL.appendingPathComponent(subdir)
                    try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
                }

                self.openDocument(withContentsOf: descriptorURL, display: true) { _, _, error in
                    if let error = error {
                        NSAlert(error: error).runModal()
                    }
                }

            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    override func openDocument(_ sender: Any?) {
        self.openDocument(
            onCompletion: { document, wasAlreadyOpen in
                print("✅ Document opened: \(String(describing: document)) (already open: \(wasAlreadyOpen))")
            },
            onCancel: {
                print("❌ User canceled open project dialog")
            }
        )
    }

    override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void
    ) {
        super.openDocument(withContentsOf: url, display: displayDocument) { document, wasAlreadyOpen, error in
            if let document {
                self.addDocument(document)
                RecentProjectsStore.documentOpened(at: url)
            } else {
                let errorMessage = error?.localizedDescription ?? "Unknown error"
                print("❌ Failed to open document: \(errorMessage)")
            }

            completionHandler(document, wasAlreadyOpen, error)
        }
    }

    override func documentClass(forType typeName: String) -> AnyClass? {
        print("📂 Resolving class for type:", typeName)
        return CircuitProjectDocument.self
    }
}

extension NSDocumentController {
    func openDocument(
        onCompletion: @escaping (NSDocument?, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let dialog = NSOpenPanel()
        dialog.title = "Open Circuit Pro Project"
        dialog.showsHiddenFiles = false
        dialog.canChooseFiles = true
        dialog.allowedContentTypes = [UTType.circuitProject]
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = false

        dialog.begin { result in
            if result == .OK, let selectedURL = dialog.url {
                let urlToOpen: URL
                if selectedURL.hasDirectoryPath {
                    let projectName = selectedURL.lastPathComponent
                    urlToOpen = selectedURL.appendingPathComponent("\(projectName).circuitproj")
                } else {
                    urlToOpen = selectedURL
                }

                self.openDocument(withContentsOf: urlToOpen, display: true) { document, wasAlreadyOpen, error in
                    if let error {
                        NSAlert(error: error).runModal()
                        onCancel()
                        return
                    }

                    guard let document else {
                        let alert = NSAlert()
                        alert.messageText = "Failed to open project"
                        alert.informativeText = "Could not open \(urlToOpen.lastPathComponent)"
                        alert.runModal()
                        onCancel()
                        return
                    }

                    onCompletion(document, wasAlreadyOpen)
                }
            } else {
                onCancel()
            }
        }
    }
}
