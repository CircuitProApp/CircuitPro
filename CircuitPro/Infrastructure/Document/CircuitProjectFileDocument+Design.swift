//
//  CircuitProjectFileDocument+Design.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI
import Foundation

@MainActor
extension CircuitProjectFileDocument {

    func addNewDesign(undoManager: UndoManager?) {
        let base = "Design"

        let indices = model.designs.compactMap { design -> Int? in
            guard design.name.hasPrefix("\(base) ") else { return nil }
            return Int(design.name.dropFirst(base.count + 1))
        }

        let next = (indices.max() ?? 0) + 1
        let newDesign = CircuitDesign(name: "\(base) \(next)")

        objectWillChange.send()
        model.designs.append(newDesign)

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.objectWillChange.send()
            if let idx = doc.model.designs.firstIndex(where: { $0.id == newDesign.id }) {
                doc.model.designs.remove(at: idx)
            }
        }
        undoManager?.setActionName("Add Design")
    }

    func renameDesign(_ design: CircuitDesign, to newName: String? = nil, undoManager: UndoManager?) {
        let targetName = (newName ?? design.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty else { return }

        let oldName = design.name

        objectWillChange.send()
        design.name = targetName

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.objectWillChange.send()
            if let idx = doc.model.designs.firstIndex(where: { $0.id == design.id }) {
                doc.model.designs[idx].name = oldName
            }
        }
        undoManager?.setActionName("Rename Design")
    }

    func deleteDesign(_ design: CircuitDesign, undoManager: UndoManager?) {
        guard let index = model.designs.firstIndex(where: { $0.id == design.id }) else { return }
        let removed = model.designs[index]

        objectWillChange.send()
        model.designs.remove(at: index)

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.objectWillChange.send()
            doc.model.designs.insert(removed, at: min(index, doc.model.designs.count))
        }
        undoManager?.setActionName("Delete Design")
    }
}

@MainActor
extension CircuitProjectFileDocument {
    func urlForComponents(of design: CircuitDesign) -> URL? {
        guard let fileURL else { return nil }
        return fileURL
            .appendingPathComponent("Designs")
            .appendingPathComponent(design.directoryName)
            .appendingPathComponent("components.json")
    }

    func designURL(_ design: CircuitDesign, in root: URL) -> URL {
        root.appendingPathComponent("Designs")
            .appendingPathComponent(design.directoryName)
    }
}
