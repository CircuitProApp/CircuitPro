//
//  TransferrableComponent.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/15/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct TransferableComponent: Transferable, Codable {
    let componentUUID: UUID
    let symbolUUID: UUID
    let properties: [ComponentProperty]
    init?(component: Component) {
        guard let symbol = component.symbol else { return nil }
        componentUUID = component.uuid
        symbolUUID    = symbol.uuid
        properties    = component.properties
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .transferableComponent)
    }
}

extension UTType {
    static let transferableComponent = UTType(exportedAs: "app.circuitpro.transferable-component-data")
}

struct DraggableModifier: ViewModifier {
    let component: Component
    func body(content: Content) -> some View {
        if let transferable = TransferableComponent(component: component) {
            content
                .draggable(transferable)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func draggableIfPresent<T: Transferable>(_ item: T?, symbol: Symbol?) -> some View {
        if let item, let symbol {
            self.draggable(item) {
               SymbolThumbnail(symbol: symbol)
            }
        } else if let item {
            self.draggable(item)
        } else {
            self
        }
    }
}
