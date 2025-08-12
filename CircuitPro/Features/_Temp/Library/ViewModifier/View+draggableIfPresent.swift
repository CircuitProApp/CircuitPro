//
//  DraggableWithCallbackModifier.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func draggableIfPresent<T: DraggableTransferable>( // Constrained to our new protocol
        _ item: T?,
        onDragInitiated: (() -> Void)? = nil
    ) -> some View {
        if let item {
            if let onDragInitiated {
                // Use the explicit .onDrag modifier
                self.onDrag {
                    // Asynchronously dispatch the callback to prevent the crash
                    DispatchQueue.main.async {
                        onDragInitiated()
                    }

                    // Explicitly create the NSItemProvider
                    let provider = NSItemProvider()
                    
                    // Get the content type directly from the item's static property
                    let contentType = T.dragContentType
                    
                    // Manually register the data representation, which is known to work
                    provider.registerDataRepresentation(forTypeIdentifier: contentType.identifier, visibility: .all) { completion in
                        let encoder = JSONEncoder()
                        do {
                            let data = try encoder.encode(item)
                            completion(data, nil)
                        } catch {
                            completion(nil, error)
                        }
                        // This is a synchronous operation, so return nil for the Progress
                        return nil
                    }
                    
                    return provider
                }
            } else {
                // If no callback is needed, the standard modern modifier is fine
                self.draggable(item)
            }
        } else {
            self
        }
    }
}
