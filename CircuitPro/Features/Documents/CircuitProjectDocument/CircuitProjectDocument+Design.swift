//
//  CircuitProjectDocument+Design.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 06.06.25.
//
import SwiftUI

extension CircuitProjectDocument {
    func addNewDesign() {
        let base = "Design"

        // Extract all numbers that follow the pattern “Design N”
        let indices = model.designs.compactMap { design -> Int? in
            guard design.name.hasPrefix("\(base) ") else { return nil }
            return Int(design.name.dropFirst(base.count + 1))
        }

        // Pick one higher than the current maximum
        let next = (indices.max() ?? 0) + 1
        let newDesign = CircuitDesign(name: "\(base) \(next)")
        model.designs.append(newDesign)

        updateChangeCount(.changeDone)
    }

    func renameDesign(_ design: CircuitDesign) {
        let trimmed = design.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        design.name = trimmed
        updateChangeCount(.changeDone)
    }

    func deleteDesign(_ design: CircuitDesign) {
        // 1. Find the element to delete
        guard let index = model.designs.firstIndex(where: { $0.id == design.id })
        else { return }

        // 2. Remember what we removed so the action can be undone
        let removed = model.designs.remove(at: index)

        // 3. Register the inverse operation with the document’s undo manager
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.model.designs.insert(removed, at: index)
            doc.updateChangeCount(.changeUndone)
        }
        undoManager?.setActionName("Delete Design")

        // 4. Make the document dirty + trigger autosave
        updateChangeCount(.changeDone)
    }
}

extension CircuitProjectDocument {

    ///  Designs/<uuid>/components.json for a certain design
    func urlForComponents(of design: CircuitDesign) -> URL? {
        guard let fileURL else { return nil }        // the root package url
        return fileURL
            .appendingPathComponent("Designs")
            .appendingPathComponent(design.directoryName)
            .appendingPathComponent("components.json")
    }
    private func designURL(_ design: CircuitDesign, in root: URL) -> URL {
        root.appendingPathComponent("Designs")
            .appendingPathComponent(design.directoryName)
    }

}
