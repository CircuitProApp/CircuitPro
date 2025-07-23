//
//  ConnectionsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/17/25.
//

import AppKit

/// Draws all nets stored in `SchematicGraph` using dedicated shape layers.
final class ConnectionsView: NSView {

    // MARK: – Data Properties
    var schematicGraph: SchematicGraph = .init() { didSet { updateLayers() } }
    var selectedIDs: Set<UUID> = []      { didSet { updateLayers() } }
    var marqueeSelectedIDs: Set<UUID> = [] { didSet { updateLayers() } }
    var magnification: CGFloat = 1.0     { didSet { updateLayers() } }

    // MARK: – Layers
    private let highlightLayer = CAShapeLayer()
    private let edgesLayer = CAShapeLayer()
    private let junctionsLayer = CAShapeLayer()
    private let verticesLayer = CAShapeLayer()

    // MARK: – Initializers
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViewAndLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViewAndLayers()
    }

    // MARK: – Setup
    private func setupViewAndLayers() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // 1. Configure Layer Styles (these are constant)
        highlightLayer.lineWidth = 5.0
        highlightLayer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        highlightLayer.fillColor = nil
        highlightLayer.lineCap = .round
        
        edgesLayer.lineWidth = 1.5
        edgesLayer.strokeColor = NSColor.systemBlue.cgColor
        edgesLayer.fillColor = nil
        
        junctionsLayer.fillColor = NSColor.systemBlue.cgColor
        
        verticesLayer.fillColor = NSColor.systemPurple.cgColor
        
        // 2. Add layers to the view's main layer in drawing order (bottom to top)
        layer?.addSublayer(highlightLayer)
        layer?.addSublayer(edgesLayer)
        layer?.addSublayer(junctionsLayer)
        layer?.addSublayer(verticesLayer)
    }

    // MARK: – Layer Updates
    /// Re-calculates and assigns the paths for all shape layers.
    private func updateLayers() {
        // Use a transaction to update all layer paths simultaneously without implicit animations.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let allSelected = selectedIDs.union(marqueeSelectedIDs)
        
        // Define constant radii
        let vertexRadius: CGFloat = 2.0
        let junctionRadius: CGFloat = 4.0

        // 1. Update Highlight Layer Path
        let highlightPath = CGMutablePath()
        for selectedID in allSelected {
            if let edge = schematicGraph.edges[selectedID],
               let startVertex = schematicGraph.vertices[edge.start],
               let endVertex = schematicGraph.vertices[edge.end] {
                highlightPath.move(to: startVertex.point)
                highlightPath.addLine(to: endVertex.point)
            }
        }
        highlightLayer.path = highlightPath
        
        // 2. Update All Edges Layer Path
        let edgesPath = CGMutablePath()
        for edge in schematicGraph.edges.values {
            if let startVertex = schematicGraph.vertices[edge.start],
               let endVertex = schematicGraph.vertices[edge.end] {
                edgesPath.move(to: startVertex.point)
                edgesPath.addLine(to: endVertex.point)
            }
        }
        edgesLayer.path = edgesPath
        
        // 3. Update Junctions and Vertices Layer Paths
        let junctionsPath = CGMutablePath()
        let verticesPath = CGMutablePath()
        
        for vertex in schematicGraph.vertices.values {
            // Path for all vertices
            let vertexRect = CGRect(x: vertex.point.x - vertexRadius, y: vertex.point.y - vertexRadius, width: vertexRadius * 2, height: vertexRadius * 2)
            verticesPath.addEllipse(in: vertexRect)
            
            // Path for junctions (determined by connection count)
            let connectionCount = schematicGraph.adjacency[vertex.id]?.count ?? 0
            var isJunction = false
            if case .pin = vertex.ownership {
                if connectionCount >= 2 { isJunction = true }
            } else {
                if connectionCount > 2 { isJunction = true }
            }
            
            if isJunction {
                let junctionRect = CGRect(x: vertex.point.x - junctionRadius, y: vertex.point.y - junctionRadius, width: junctionRadius * 2, height: junctionRadius * 2)
                junctionsPath.addEllipse(in: junctionRect)
            }
        }
        junctionsLayer.path = junctionsPath
        verticesLayer.path = verticesPath
        
        CATransaction.commit()
    }
}
