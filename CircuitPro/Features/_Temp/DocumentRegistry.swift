//
//  DocumentRegistry.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import AppKit

final class DocumentRegistry: ObservableObject {
    static let shared = DocumentRegistry()

    private var docs: [DocumentID: CircuitProjectDocument] = [:]
    private var urlToID: [URL: DocumentID] = [:]
    private let lock = NSLock()

    func register(_ doc: CircuitProjectDocument, url: URL?) -> DocumentID {
        lock.lock(); defer { lock.unlock() }
        if let url, let existing = urlToID[url] {
            docs[existing] = doc
            return existing
        }
        let id = DocumentID()
        docs[id] = doc
        if let url { urlToID[url] = id }
        return id
    }

    func document(for id: DocumentID) -> CircuitProjectDocument? {
        lock.lock(); defer { lock.unlock() }
        return docs[id]
    }

    func id(for url: URL) -> DocumentID? {
        lock.lock(); defer { lock.unlock() }
        return urlToID[url]
    }

    func close(id: DocumentID) {
        lock.lock(); defer { lock.unlock() }
        guard let doc = docs[id] else { return }
        if let url = doc.fileURL { urlToID.removeValue(forKey: url) }
        docs.removeValue(forKey: id)
        NSDocumentController.shared.removeDocument(doc)
    }

    @MainActor
    func save(id: DocumentID) {
        guard let doc = document(for: id) else { return }
        // This will present a save panel if needed and write changes
        doc.save(nil)
    }
}
