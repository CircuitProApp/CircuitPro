import SwiftUI
import UniformTypeIdentifiers

struct TransferableComponent: Transferable, Codable {

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


extension View {
    @ViewBuilder
    func draggableIfPresent<T: Transferable>(
        _ item: T?,
        symbol: Symbol? = nil,
        onDragInitiated: (() -> Void)? = nil
    ) -> some View {
        if let item {
            self.draggable(item) {
                // The Group unifies the two conditional branches into a single View expression.
                Group {
//                    if let symbol {
//                        SymbolThumbnail(symbol: symbol)
//                    } else {
                        // This mimics the default drag preview behavior.
                        self          
//                    }
                }
                // We attach the onAppear modifier to the Group.
                // The preview view is created exactly once when the drag begins,
                // so onAppear is the perfect hook to trigger the callback.
                .onAppear {
                    onDragInitiated?()
                }
            }
        } else {
            self
        }
    }
}
