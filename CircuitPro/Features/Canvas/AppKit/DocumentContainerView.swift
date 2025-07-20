//
//  DocumentContainerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 20.07.25.
//

import AppKit

final class DocumentContainerView: NSView {

    let workspaceBackgroundView = WorkspaceBackgroundView()
    let workbenchView: WorkbenchView

    override var isFlipped: Bool { true }

    init(workbench: WorkbenchView) {
        self.workbenchView = workbench
        super.init(frame: .zero)
        
        addSubview(workspaceBackgroundView)
        addSubview(workbenchView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        workspaceBackgroundView.frame = bounds
        
        let wbSize = workbenchView.frame.size
        let mySize = bounds.size
        
        let origin = CGPoint(
            x: (mySize.width - wbSize.width) / 2,
            y: (mySize.height - wbSize.height) / 2
        )
        
        workbenchView.frame = CGRect(origin: origin, size: wbSize)
    }
}
