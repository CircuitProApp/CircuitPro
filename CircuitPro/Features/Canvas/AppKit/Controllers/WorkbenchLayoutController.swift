//
//  WorkbenchLayoutController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 15.07.25.
//

import AppKit

final class WorkbenchLayoutController {

    // 1. Init
    unowned let workbench: WorkbenchView

    init(host: WorkbenchView) {
        self.workbench = host
        buildHierarchy()
    }

    // 2. Hierarchy builder
    private func buildHierarchy() {

        // 1 Background
        let background = DottedBackgroundView()
        background.translatesAutoresizingMaskIntoConstraints = false
        workbench.addSubview(background)
        workbench.backgroundView = background

        // 2 Drawing sheet
        let sheet = DrawingSheetView(frame: .zero)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        workbench.addSubview(sheet)
        workbench.sheetView = sheet

        // Pin background and sheet to workbench edges
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: workbench.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: workbench.trailingAnchor),
            background.topAnchor.constraint(equalTo: workbench.topAnchor),
            background.bottomAnchor.constraint(equalTo: workbench.bottomAnchor),
            
            sheet.leadingAnchor.constraint(equalTo: workbench.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: workbench.trailingAnchor),
            sheet.topAnchor.constraint(equalTo: workbench.topAnchor),
            sheet.bottomAnchor.constraint(equalTo: workbench.bottomAnchor)
        ])

        let connections = ConnectionsView(frame: workbench.bounds)
        connections.autoresizingMask = [.width, .height]
        workbench.addSubview(connections)
        workbench.connectionsView = connections
        
        // 3 Elements
        let elements = ElementsView(frame: workbench.bounds)
        elements.autoresizingMask = [.width, .height]
        workbench.addSubview(elements)
        workbench.elementsView = elements

        // 4 Preview
        let preview = PreviewView(frame: workbench.bounds)
        preview.autoresizingMask = [.width, .height]
        preview.workbench = workbench
        workbench.addSubview(preview)
        workbench.previewView = preview

        // 5 Handles
        let handles = HandlesView(frame: workbench.bounds)
        handles.autoresizingMask = [.width, .height]
        workbench.addSubview(handles)
        workbench.handlesView = handles

        // 6 Marquee
        let marquee = MarqueeView()
        marquee.autoresizingMask = [.width, .height]
        workbench.addSubview(marquee)
        workbench.marqueeView = marquee

        // 7 Crosshairs
        let crosshairs = CrosshairsView()
        crosshairs.autoresizingMask = [.width, .height]
        workbench.addSubview(crosshairs)
        workbench.crosshairsView = crosshairs
    }
}

