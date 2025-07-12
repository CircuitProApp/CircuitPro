//
//  PreviewView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

final class PreviewView: NSView {
    
    var selectedTool: AnyCanvasTool? {
        didSet { needsDisplay = true }
    }
    var magnification: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }
    
    // Using a weak reference to the workbench to access necessary context
    // without creating a retain cycle. The workbench owns the PreviewView.
    weak var workbench: WorkbenchView?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              var tool = selectedTool,
              tool.id != "cursor",
              let workbench = workbench,
              let win = window else { return }

        let mouseWin = win.mouseLocationOutsideOfEventStream
        let mouse = convert(mouseWin, from: nil)

        let pinCount = workbench.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 }
        let padCount = workbench.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 }

        let ctxInfo = CanvasToolContext(
            existingPinCount: pinCount,
            existingPadCount: padCount,
            selectedLayer: workbench.selectedLayer,
            magnification: magnification
        )

        let snappedMouse = workbench.snap(mouse)
        
        ctx.saveGState()
        tool.drawPreview(in: ctx, mouse: snappedMouse, context: ctxInfo)
        ctx.restoreGState()
        
        // Persist any state changes the tool might have made
        workbench.selectedTool = tool
    }
}
