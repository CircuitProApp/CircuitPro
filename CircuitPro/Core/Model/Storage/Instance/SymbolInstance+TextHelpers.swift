//
//  SymbolInstance+TextHelpers.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/1/25.
//

import Foundation
import SwiftUI

/// This extension centralizes all business logic related to managing the text
/// elements owned by a SymbolInstance.
extension SymbolInstance {
    
    /// Toggles the visibility of a text element identified by its `TextSource`.
    /// This method uses the power of the `ResolvableBacked` conformance to find,
    /// update, or create the necessary override or instance.
    func toggleVisibility(for source: TextSource) {
        // Find the existing text, if any. `.resolvedItems` is free from ResolvableBacked!
        if var existingText = self.resolvedItems.first(where: { $0.contentSource == source }) {
            // A text item exists, so we just toggle its visibility and apply the change.
            existingText.isVisible.toggle()
            self.apply(existingText) // `.apply` handles override/instance logic automatically.
        } else {
            // No text exists, so we create a new, visible instance from scratch.
            let newTextInstance = CircuitText.Instance(
                id: UUID(),
                contentSource: source,
                relativePosition: .zero, // Or some other default position
                anchorPosition: .zero,
                isVisible: true
            )
            self.add(newTextInstance) // `.add` is also free from ResolvableBacked.
        }
    }
    
    /// Gets the display options for a given text source.
    func displayOptions(for source: TextSource) -> TextDisplayOptions {
        return self.resolvedItems.first(where: { $0.contentSource == source })?.displayOptions ?? .default
    }
    
    /// Sets the display options for a given text source.
    func setDisplayOptions(for source: TextSource, options: TextDisplayOptions) {
        if var existingText = self.resolvedItems.first(where: { $0.contentSource == source }) {
            // The text already exists; update its options and apply.
            existingText.displayOptions = options
            self.apply(existingText)
        } else {
            // No text exists. Create a new, *hidden* instance that just holds these options.
            // When it's toggled visible later, it will have the correct formatting.
            var newTextInstance = CircuitText.Instance(
                id: UUID(),
                contentSource: source,
                relativePosition: .zero,
                anchorPosition: .zero,
                isVisible: false // Important: don't show it yet
            )
            newTextInstance.displayOptions = options
            self.add(newTextInstance)
        }
    }
}
