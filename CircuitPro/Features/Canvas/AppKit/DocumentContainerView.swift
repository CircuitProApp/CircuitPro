//
//  DocumentContainerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 20.07.25.
//

import AppKit

final class DocumentContainerView: NSView {

    let documentBackgroundView = DocumentBackgroundView()
    let workbenchView: WorkbenchView

    init(workbench: WorkbenchView) {
        self.workbenchView = workbench
        super.init(frame: .zero)
        
        // 1. Configure WorkbenchView
        setupWorkbenchViewShadow()
        
        // 2. Add subviews
        addSubview(documentBackgroundView)
        addSubview(workbenchView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupWorkbenchViewShadow() {
        workbenchView.wantsLayer = true
        
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 7.0
        
        workbenchView.shadow = shadow
    }

    override func layout() {
        super.layout()
        documentBackgroundView.frame = bounds
        
        let wbSize = workbenchView.frame.size
        let mySize = bounds.size
        
        let origin = CGPoint(
            x: (mySize.width - wbSize.width) / 2,
            y: (mySize.height - wbSize.height) / 2
        )
        
        workbenchView.frame = CGRect(origin: origin, size: wbSize)
    }
}
