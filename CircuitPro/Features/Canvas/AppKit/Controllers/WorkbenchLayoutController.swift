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

    // 2. Stored references
    private var sheetWidthC:   NSLayoutConstraint?
    private var sheetHeightC:  NSLayoutConstraint?

    // 3. Hierarchy builder
    private func buildHierarchy() {

        // 1 Background
        // let background = BackgroundView(frame: workbench.bounds)
        // background.autoresizingMask = [.width, .height]
        // workbench.addSubview(background)
        // workbench.backgroundView = background

        // 2 Drawing sheet
        let sheet = DrawingSheetView(frame: .zero)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        workbench.addSubview(sheet)
        workbench.sheetView = sheet

        let size = sheet.intrinsicContentSize
        sheetWidthC  = sheet.widthAnchor .constraint(equalToConstant: size.width)
        sheetHeightC = sheet.heightAnchor.constraint(equalToConstant: size.height)
        let leading  = sheet.leadingAnchor.constraint(equalTo: workbench.leadingAnchor, constant: 2500)
        let top      = sheet.topAnchor    .constraint(equalTo: workbench.topAnchor,    constant: 2500)
        NSLayoutConstraint.activate([sheetWidthC!, sheetHeightC!, leading, top])

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
        let marquee = MarqueeView(frame: workbench.bounds)
        marquee.autoresizingMask = [.width, .height]
        workbench.addSubview(marquee)
        workbench.marqueeView = marquee

        // 7 Crosshairs
        let crosshairs = CrosshairsView(frame: workbench.bounds)
        crosshairs.autoresizingMask = [.width, .height]
        workbench.addSubview(crosshairs)
        workbench.crosshairsView = crosshairs
    }

    // 4. Constraint maintenance
    func refreshSheetSize() {
        guard let sheet = workbench.sheetView else { return }
        let size = sheet.intrinsicContentSize
        sheetWidthC?.constant  = size.width
        sheetHeightC?.constant = size.height
    }
}
