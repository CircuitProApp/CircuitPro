//
//  ElementsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//  Refactored: 17.07.25 (removed connection-specific code)
//

import AppKit

final class ElementsView: NSView {

    // MARK: – Data
    var elements: [CanvasElement] = [] { didSet { needsDisplay = true } }
    var selectedIDs: Set<UUID> = []   { didSet { needsDisplay = true } }
    var marqueeSelectedIDs: Set<UUID> = [] { didSet { needsDisplay = true } }

    // MARK: – View flags
    override var isFlipped: Bool  { true  }
    override var isOpaque: Bool   { false }

    // MARK: – Drawing
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let allSelected = selectedIDs.union(marqueeSelectedIDs)

        for element in elements {
            let isSelected = allSelected.contains(element.id)
            element.drawable.draw(in: ctx, selected: isSelected)
        }
    }
}
