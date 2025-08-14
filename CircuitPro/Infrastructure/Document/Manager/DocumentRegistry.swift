//
//  DocumentRegistry.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI
import WelcomeWindow

@MainActor
final class DocumentRegistry: ObservableObject {
    static let shared = DocumentRegistry()

    private var docs: [DocumentID: CircuitProjectFileDocument] = [:]
    private var urlToID: [URL: DocumentID] = [:]
    private var securedURLs: Set<URL> = []

    @discardableResult
    func register(_ doc: CircuitProjectFileDocument, url: URL?) -> DocumentID {
        let id = DocumentID()
        docs[id] = doc
        if let url {
            urlToID[url] = id
            if RecentsStore.beginAccessing(url) {
                securedURLs.insert(url)
            }
        }
        return id
    }

    func document(for id: DocumentID) -> CircuitProjectFileDocument? { docs[id] }

    func id(for url: URL) -> DocumentID? { urlToID[url] }

    func close(id: DocumentID) {
        guard let doc = docs[id] else { return }
        if let url = doc.fileURL {
            urlToID.removeValue(forKey: url)
            if securedURLs.remove(url) != nil {
                RecentsStore.endAccessing(url)
            }
        }
        docs.removeValue(forKey: id)
    }

    // Call this after a Save As that changed the URL.
    func updateURL(for id: DocumentID, to newURL: URL) {
        guard let doc = docs[id] else { return }
        let oldURL = doc.fileURL

        if let oldURL {
            urlToID.removeValue(forKey: oldURL)
            if securedURLs.remove(oldURL) != nil {
                RecentsStore.endAccessing(oldURL)
            }
        }

        urlToID[newURL] = id
        if RecentsStore.beginAccessing(newURL) {
            securedURLs.insert(newURL)
        }

        doc.fileURL = newURL
    }
}
