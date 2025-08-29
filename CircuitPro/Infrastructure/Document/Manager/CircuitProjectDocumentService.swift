//
//  CircuitProjectDocumentService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import AppKit
import UniformTypeIdentifiers
import WelcomeWindow
import SwiftDataPacks

@MainActor
final class CircuitProjectDocumentService {
    static let shared = CircuitProjectDocumentService()

    func createWithDialog(
        defaultName: String = "Untitled",
        onDialogPresented: @escaping () -> Void = {},
        onCompletion: @escaping (DocumentID) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        let panel = NSSavePanel()
        panel.prompt = "Create"
        panel.title = "Create New Project"
        panel.nameFieldStringValue = "\(defaultName).\(UTType.circuitProject.preferredFilenameExtension ?? "circuitproj")"
        panel.allowedContentTypes = [.circuitProject]
        panel.canCreateDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        panel.level = .modalPanel

        DispatchQueue.main.async { onDialogPresented() }

        guard panel.runModal() == .OK, let url = panel.url else {
            onCancel(); return
        }

        do {
            let name = url.deletingPathExtension().lastPathComponent
            let doc = CircuitProjectFileDocument(newWithName: name)
            try doc.write(to: url)

            let id = DocumentRegistry.shared.register(doc, url: url)
            RecentsStore.documentOpened(at: url)

            onCompletion(id)
        } catch {
            NSAlert(error: error).runModal()
            onCancel()
        }
    }

    func openWithDialog(
        using packManager: SwiftDataPackManager,
        onDialogPresented: @escaping () -> Void = {},
        onCompletion: @escaping (DocumentID) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.allowedContentTypes = [.circuitProject]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.level = .modalPanel

        panel.begin { result in
            guard result == .OK, let url = panel.url else {
                onCancel(); return
            }
            Task { @MainActor in
                self.open(at: url, using: packManager, onCompletion: onCompletion, onCancel: onCancel)
            }
        }

        onDialogPresented()
    }

    func open(
         at url: URL,
         using packManager: SwiftDataPackManager,
         onCompletion: @escaping (DocumentID) -> Void = { _ in },
         onCancel: @escaping () -> Void = {}
     ) {
         do {
             // If document is already open, just focus it.
             if let existingID = DocumentRegistry.shared.id(for: url) {
                 onCompletion(existingID)
                 return
             }

             // 1. Initialize the document, which now performs hydration internally.
             let doc = try CircuitProjectFileDocument(fileURL: url, container: packManager.mainContainer)
             
             // 2. Register the fully hydrated document.
             let id = DocumentRegistry.shared.register(doc, url: url)

             RecentsStore.documentOpened(at: url)
             onCompletion(id)
         } catch {
             NSAlert(error: error).runModal()
             onCancel()
         }
     }


    func save(id: DocumentID) {
        guard let doc = DocumentRegistry.shared.document(for: id) else { return }
        do {
            if let url = doc.fileURL {
                // Regular Save
                try doc.write(to: url)
            } else {
                // Save As…
                let panel = NSSavePanel()
                panel.prompt = "Save"
                panel.title = "Save Project"
                panel.nameFieldStringValue = "\(doc.model.name).\(UTType.circuitProject.preferredFilenameExtension ?? "circuitproj")"
                panel.allowedContentTypes = [.circuitProject]
                panel.canCreateDirectories = true
                panel.treatsFilePackagesAsDirectories = true
                panel.level = .modalPanel

                if panel.runModal() == .OK, let newURL = panel.url {
                    try doc.write(to: newURL)
                    DocumentRegistry.shared.updateURL(for: id, to: newURL)
                    RecentsStore.documentOpened(at: newURL)
                }
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
