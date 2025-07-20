//
//  DocumentContainerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 20.07.25.
//

import AppKit

final class DocumentContainerView: NSView {

    let pasteboardView = PasteboardView()
    let workbenchView: WorkbenchView

    init(workbench: WorkbenchView) {
        self.workbenchView = workbench
        super.init(frame: .zero)
        
        pasteboardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pasteboardView)
        
        workbenchView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(workbenchView)

        NSLayoutConstraint.activate([
            pasteboardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pasteboardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pasteboardView.topAnchor.constraint(equalTo: topAnchor),
            pasteboardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            workbenchView.centerXAnchor.constraint(equalTo: centerXAnchor),
            workbenchView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
