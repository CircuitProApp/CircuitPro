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
        if let r = rect {
            let ids = workbench.elements
                         .filter { $0.boundingBox.intersects(r) }
                         .map(\.id)
            workbench.marqueeSelectedIDs = Set(ids)
        }
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