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

//    func openWithDialog(
//        onDialogPresented: @escaping () -> Void = {},
//        onCompletion: @escaping (DocumentID) -> Void = { _ in },
//        onCancel: @escaping () -> Void = {}
//    ) {
//        let panel = NSOpenPanel()
//        panel.title = "Open Project"
//        panel.allowedContentTypes = [.circuitProject]
//        panel.canChooseFiles = true
//        panel.canChooseDirectories = false
//        panel.allowsMultipleSelection = false
//        panel.treatsFilePackagesAsDirectories = false
//        panel.level = .modalPanel
//
//        panel.begin { result in
//            guard result == .OK, let url = panel.url else {
//                onCancel(); return
//            }
//            Task { @MainActor in
//                self.open(at: url, onCompletion: onCompletion, onCancel: onCancel)
//            }
//        }
//
//        onDialogPresented()
//    }

    func open(
         at url: URL,
         // --- ADD THIS PARAMETER ---
         using packManager: SwiftDataPackManager,
         onCompletion: @escaping (DocumentID) -> Void = { _ in },
         onCancel: @escaping () -> Void = {}
     ) {
         do {
             if let existing = DocumentRegistry.shared.id(for: url) {
                 onCompletion(existing)
                 return
             }

             // At this point, the file is successfully read into memory.
             let doc = try CircuitProjectFileDocument(fileURL: url)
             
             // --- OUR TEST GOES HERE ---
             print("--- Document Loaded, Performing Hydration Test ---")
             let context = ModelContext(packManager.mainContainer)
             let descriptor = FetchDescriptor<ComponentDefinition>()
             
             do {
                 let definitions = try context.fetch(descriptor)
                 print("SUCCESS: Found \(definitions.count) ComponentDefinitions in the main container.")
                 for (index, def) in definitions.enumerated() {
                     if index < 5 { // Print first 5 to avoid spamming the console
                         print("  - \(def.name)")
                     }
                 }
                 if definitions.count > 5 {
                     print("  - ... and \(definitions.count - 5) more.")
                 }
             } catch {
                 print("ERROR: Could not fetch ComponentDefinitions: \(error.localizedDescription)")
             }
             print("--- Test Complete ---")
             // --- END OF TEST ---

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
