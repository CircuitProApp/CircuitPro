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
        // Sizes are now constant and do not scale with magnification.
        let lineWidth: CGFloat = 1.5
        let vertexRadius: CGFloat = 2.0
        let junctionRadius: CGFloat = 4.0
        let highlightLineWidth: CGFloat = 5.0

        // 1. Draw Selected Edge Highlights
        ctx.setStrokeColor(NSColor.systemYellow.cgColor)
        ctx.setLineWidth(highlightLineWidth)
        ctx.setLineCap(.round)
        
        for selectedID in allSelected {
            if let edge = schematicGraph.edges[selectedID] {
                guard let startVertex = schematicGraph.vertices[edge.start],
                      let endVertex = schematicGraph.vertices[edge.end] else { continue }
                
                ctx.move(to: startVertex.point)
                ctx.addLine(to: endVertex.point)
                ctx.strokePath()
            }
        }
        ctx.setLineCap(.butt) // Reset

        // 2. Draw All Edges (on top of highlights)
        ctx.setStrokeColor(NSColor.systemGreen.cgColor)
        ctx.setLineWidth(lineWidth)
        
        for edge in schematicGraph.edges.values {
            guard let startVertex = schematicGraph.vertices[edge.start],
                  let endVertex = schematicGraph.vertices[edge.end] else { continue }
            
            ctx.move(to: startVertex.point)
            ctx.addLine(to: endVertex.point)
            ctx.strokePath()
        }
        
        // 3. Draw Junctions
        ctx.setFillColor(NSColor.systemGreen.cgColor)
        
        for vertex in schematicGraph.vertices.values {
            if schematicGraph.adjacency[vertex.id]?.count ?? 0 > 2 {
                let rect = CGRect(x: vertex.point.x - junctionRadius,
                                  y: vertex.point.y - junctionRadius,
                                  width: junctionRadius * 2,
                                  height: junctionRadius * 2)
                ctx.fillEllipse(in: rect)
            }
        }
        
        // 4. Draw Vertices (with no selection highlight)
        ctx.setFillColor(NSColor.systemBlue.cgColor) // Always use default color
        
        for vertex in schematicGraph.vertices.values {
            let rect = CGRect(x: vertex.point.x - vertexRadius,
                              y: vertex.point.y - vertexRadius,
                              width: vertexRadius * 2,
                              height: vertexRadius * 2)
            ctx.fillEllipse(in: rect)
        }
    }
}
