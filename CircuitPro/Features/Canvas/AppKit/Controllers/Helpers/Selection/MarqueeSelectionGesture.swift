//
//  MarqueeSelectionGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//


import AppKit

/// Handles click-drag-release marquee selection.
final class MarqueeSelectionGesture {

    unowned let workbench: WorkbenchView

    private var origin: CGPoint?
    private var rect:   CGRect? {
        didSet { workbench.marqueeView?.rect = rect }
    }

    init(workbench: WorkbenchView) { self.workbench = workbench }

    // start when the cursor tool is active and the hit-test finds nothing
    func begin(at p: CGPoint) {
        origin = p
        rect   = nil
    }

    func drag(to p: CGPoint) {
        guard let o = origin else { return }
        rect = CGRect(origin: o, size: .zero).union(CGRect(origin: p, size: .zero))
        
        guard let r = rect else { return }

        // 1. Select canvas elements
        let elementIDs = workbench.elements
            .filter { $0.boundingBox.intersects(r) }
            .map(\.id)

        // 2. Select schematic edges
        let edgeIDs = workbench.schematicGraph.edges.values.compactMap { edge -> UUID? in
            guard let startVertex = workbench.schematicGraph.vertices[edge.start],
                  let endVertex = workbench.schematicGraph.vertices[edge.end] else {
                return nil
            }
            
            // Create a bounding box for the edge segment.
            let edgeRect = CGRect(origin: startVertex.point, size: .zero)
                .union(.init(origin: endVertex.point, size: .zero))
            
            // Select the edge if its bounding box intersects the marquee.
            return r.intersects(edgeRect) ? edge.id : nil
        }

        // 3. Combine and update marquee selection
        workbench.marqueeSelectedIDs = Set(elementIDs).union(edgeIDs)
    }

    func end() {
        if origin != nil {
            workbench.selectedIDs = workbench.marqueeSelectedIDs
            workbench.onSelectionChange?(workbench.selectedIDs)
        }
        workbench.marqueeSelectedIDs.removeAll()
        origin = nil
        rect   = nil
    }

    var active: Bool { origin != nil }
}