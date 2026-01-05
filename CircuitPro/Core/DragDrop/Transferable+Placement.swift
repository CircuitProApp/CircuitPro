//
//  TransferablePlacement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//
import SwiftUI
import UniformTypeIdentifiers

/// A transferable object that represents an existing, unplaced component instance
/// being dragged from the navigator onto the layout canvas.
struct TransferablePlacement: DraggableTransferable {

    static var dragContentType: UTType { .transferablePlacement }

    /// The unique ID of the ComponentInstance being placed.
    let componentInstanceID: UUID

    init(componentInstanceID: UUID) {
        self.componentInstanceID = componentInstanceID
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .transferablePlacement)
    }
}

// Add the new, unique type identifier.
extension UTType {
    static let transferablePlacement = UTType(exportedAs: "app.circuitpro.transferable-placement-data")
}
