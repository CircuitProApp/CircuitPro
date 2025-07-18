//
//  ConnectionsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/17/25.
//


import AppKit

/// Draws all nets stored in `NetList`.
final class ConnectionsView: NSView {

    // MARK: – Data pushed in by WorkbenchView
    var schematicGraph: SchematicGraph = .init()             { didSet { needsDisplay = true } }
    var selectedIDs: Set<UUID> = []            { didSet { needsDisplay = true } }
    var marqueeSelectedIDs: Set<UUID> = []     { didSet { needsDisplay = true } }
    var allPinPositions: [CGPoint] = []        { didSet { needsDisplay = true } }
    var magnification: CGFloat = 1.0           { didSet { needsDisplay = true } }

    // MARK: – View flags
    override var isFlipped: Bool  { true }
    override var isOpaque: Bool   { false }

    // MARK: – Drawing
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let allSelected = selectedIDs.union(marqueeSelectedIDs)


    }
}
