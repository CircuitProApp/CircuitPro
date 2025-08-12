import SwiftUI
import UniformTypeIdentifiers

struct TransferableComponent: DraggableTransferable {

    static var dragContentType: UTType { .transferableComponent }
    
    let componentUUID: UUID
    let symbolUUID: UUID
    
    init?(component: Component) {
        guard let symbol = component.symbol else { return nil }
        componentUUID = component.uuid
        symbolUUID    = symbol.uuid
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .transferableComponent)
    }
}

extension UTType {
    static let transferableComponent = UTType(exportedAs: "app.circuitpro.transferable-component-data")
}
