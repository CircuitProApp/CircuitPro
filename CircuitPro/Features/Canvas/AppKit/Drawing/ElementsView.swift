//
//  ElementsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

final class ElementsView: NSView {
    
    var elements: [CanvasElement] = [] {
        didSet { needsDisplay = true }
    }
    var selectedIDs: Set<UUID> = [] {
        didSet { needsDisplay = true }
    }
    var marqueeSelectedIDs: Set<UUID> = [] {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let allSelectedIDs = selectedIDs.union(marqueeSelectedIDs)
        
        let allPinPositions = elements.compactMap { element -> SymbolElement? in
            if case .symbol(let symbol) = element { return symbol }
            return nil
        }.flatMap { symbolElement -> [CGPoint] in
            symbolElement.symbol.pins.map { pin in
                return symbolElement.instance.position + pin.position.rotated(by: symbolElement.instance.rotation)
            }
        }
        
        for element in elements {
            if case .connection(let conn) = element {
                conn.draw(in: ctx, with: allSelectedIDs, allPinPositions: allPinPositions)
            } else {
                let isSelected = allSelectedIDs.contains(element.id)
                element.drawable.draw(in: ctx, selected: isSelected)
            }
        }
    }
}
