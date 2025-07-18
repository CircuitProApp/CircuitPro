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
        let lineWidth = 1.5 / magnification
        let vertexRadius = 3.0 / magnification

        // Draw Edges
        ctx.setStrokeColor(NSColor.systemGreen.cgColor)
        ctx.setLineWidth(lineWidth)
        
        for edge in schematicGraph.edges.values {
            guard let startVertex = schematicGraph.vertices[edge.start],
                  let endVertex = schematicGraph.vertices[edge.end] else { continue }
            
            ctx.move(to: startVertex.point)
            ctx.addLine(to: endVertex.point)
            ctx.strokePath()
        }
        
        // Draw Vertices
        ctx.setFillColor(NSColor.systemBlue.cgColor)
        
        for vertex in schematicGraph.vertices.values {
            let rect = CGRect(x: vertex.point.x - vertexRadius,
                              y: vertex.point.y - vertexRadius,
                              width: vertexRadius * 2,
                              height: vertexRadius * 2)
            ctx.fillEllipse(in: rect)
        }
    }
}
