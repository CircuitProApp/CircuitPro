import AppKit

struct DrawingSheetRL: CKView {
    @CKContext var context
    @CKEnvironment var environment

    private let inset: CGFloat = 20
    private let cellHeight: CGFloat = 25
    private let cellPad: CGFloat = 10
    private let unitsPerMM: CGFloat = 10

    private let bakedCellValues: [String: String] = [
        "Unit": "mm"
    ]

    @CKViewBuilder var body: some CKView {
        let hSpacing = 10 * unitsPerMM
        let vSpacing = 10 * unitsPerMM

        let metrics = DrawingMetrics(
            viewBounds: context.canvasBounds,
            inset: inset,
            horizontalTickSpacing: hSpacing,
            verticalTickSpacing: vSpacing,
            cellHeight: cellHeight,
            cellValues: bakedCellValues
        )

        let backgroundColor = environment.canvasTheme.backgroundColor
        let markerColor = NSColor(cgColor: environment.canvasTheme.sheetMarkerColor) ?? .black

        CKGroup {
            backgroundLayer(metrics: metrics, backgroundColor: backgroundColor)
            CKBorderDrawer()
                .layer(metrics: metrics, lineColor: markerColor.cgColor)
            if !bakedCellValues.isEmpty {
                CKTitleBlockDrawer(
                    cellValues: bakedCellValues,
                    lineColor: markerColor,
                    textColor: markerColor,
                    cellPad: cellPad,
                    cellHeight: cellHeight,
                    safeFont: safeFont
                )
                .layer(metrics: metrics)
            }
            for position in [CKRulerDrawer.Position.top, .bottom, .left, .right] {
                CKRulerDrawer(
                    position: position,
                    lineColor: markerColor,
                    textColor: markerColor,
                    safeFont: safeFont,
                    showLabels: true
                )
                .layer(metrics: metrics)
            }
        }
    }

    private func backgroundLayer(metrics: DrawingMetrics, backgroundColor: CGColor) -> some CKView {
        let rulerBGPath = CGMutablePath()
        rulerBGPath.addRect(metrics.outerBounds)
        rulerBGPath.addRect(metrics.innerBounds)

        return CKGroup {
            CKPath(path: rulerBGPath).fill(backgroundColor, rule: .evenOdd)
            if metrics.titleBlockFrame.height > 0 {
                let titlePath = CGPath(rect: metrics.titleBlockFrame, transform: nil)
                CKPath(path: titlePath).fill(backgroundColor)
            }
        }
    }

    private func safeFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        if #available(macOS 11.0, *) {
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }
}

private struct CKBorderDrawer {
    @CKViewBuilder func layer(metrics: DrawingMetrics, lineColor: CGColor) -> some CKView {
        let outerPath = CGPath(rect: metrics.outerBounds.insetBy(dx: 0.5, dy: 0.5), transform: nil)
        let innerPath = CGPath(rect: metrics.innerBounds, transform: nil)

        CKGroup {
            CKPath(path: outerPath).stroke(lineColor, width: 1.0)
            CKPath(path: innerPath).stroke(lineColor, width: 1.0)
        }
    }
}

private struct CKRulerDrawer {
    enum Position { case top, bottom, left, right }

    let position: Position
    let lineColor: NSColor
    let textColor: NSColor
    let safeFont: (CGFloat, NSFont.Weight) -> NSFont
    let showLabels: Bool

    @CKViewBuilder func layer(metrics: DrawingMetrics) -> some CKView {
        let spacing = isVertical() ? metrics.verticalTickSpacing : metrics.horizontalTickSpacing
        if spacing > 0 {
            CKGroup {
                ticksLayer(metrics: metrics, tickSpacing: spacing)
                if showLabels {
                    labelsLayer(metrics: metrics, tickSpacing: spacing)
                }
            }
        } else {
            CKEmpty()
        }
    }

    private func ticksLayer(metrics: DrawingMetrics, tickSpacing: CGFloat) -> some CKView {
        let tickPath = CGMutablePath()
        let inner = metrics.innerBounds
        let outer = metrics.outerBounds

        if isVertical() {
            let xStart = isPrimaryEdge() ? inner.minX : inner.maxX
            let xEnd = isPrimaryEdge() ? outer.minX : outer.maxX
            for y in stride(from: inner.maxY - tickSpacing, to: inner.minY, by: -tickSpacing) {
                tickPath.move(to: CGPoint(x: xStart, y: y))
                tickPath.addLine(to: CGPoint(x: xEnd, y: y))
            }
        } else {
            let yStart = isPrimaryEdge() ? inner.minY : inner.maxY
            let yEnd = isPrimaryEdge() ? outer.minY : outer.maxY
            for x in stride(from: inner.minX + tickSpacing, to: inner.maxX, by: tickSpacing) {
                tickPath.move(to: CGPoint(x: x, y: yStart))
                tickPath.addLine(to: CGPoint(x: x, y: yEnd))
            }
        }

        return CKPath(path: tickPath).stroke(lineColor.cgColor, width: 1.0)
    }

    private func labelsLayer(metrics: DrawingMetrics, tickSpacing: CGFloat) -> some CKView {
        let font = safeFont(9, .regular)
        let inner = metrics.innerBounds
        let outer = metrics.outerBounds
        let path = CGMutablePath()

        if isVertical() {
            let xLabel = isPrimaryEdge() ? (inner.minX + outer.minX) / 2 : (inner.maxX + outer.maxX) / 2
            let yRange = stride(from: inner.maxY - tickSpacing, to: inner.minY, by: -tickSpacing)

            for (i, y) in yRange.enumerated() {
                let cellMidY = y + tickSpacing / 2
                let text = labelForIndex(i, isNumber: false)
                let textPath = CKText.path(for: text, font: font)
                let textBounds = textPath.boundingBoxOfPath

                let position = CGPoint(x: xLabel - textBounds.width / 2, y: cellMidY - textBounds.height / 2)
                let transform = CGAffineTransform(translationX: position.x - textBounds.minX, y: position.y - textBounds.minY)

                path.addPath(textPath, transform: transform)
            }
        } else {
            let yLabel = isPrimaryEdge() ? (inner.minY + outer.minY) / 2 : (inner.maxY + outer.maxY) / 2
            let xRange = stride(from: inner.minX + tickSpacing, to: inner.maxX, by: tickSpacing)

            for (i, x) in xRange.enumerated() {
                let cellMidX = x - tickSpacing / 2
                let text = labelForIndex(i, isNumber: true)
                let textPath = CKText.path(for: text, font: font)
                let textBounds = textPath.boundingBoxOfPath

                let position = CGPoint(x: cellMidX - textBounds.width / 2, y: yLabel - textBounds.height / 2)
                let transform = CGAffineTransform(translationX: position.x - textBounds.minX, y: position.y - textBounds.minY)

                path.addPath(textPath, transform: transform)
            }
        }

        return CKPath(path: path).fill(textColor.cgColor)
    }

    private func isVertical() -> Bool { position == .left || position == .right }
    private func isPrimaryEdge() -> Bool { position == .top || position == .left }

    private func labelForIndex(_ index: Int, isNumber: Bool) -> String {
        if isNumber { return "\(index + 1)" }
        var number = index
        var label = ""
        repeat {
            label = String(UnicodeScalar(65 + (number % 26))!) + label
            number = number / 26 - 1
        } while number >= 0
        return label
    }
}

private struct CKTitleBlockDrawer {
    let cellValues: [String: String]
    let lineColor: NSColor
    let textColor: NSColor
    let cellPad: CGFloat
    let cellHeight: CGFloat
    let safeFont: (CGFloat, NSFont.Weight) -> NSFont

    @CKViewBuilder func layer(metrics: DrawingMetrics) -> some CKView {
        let rect = metrics.titleBlockFrame
        if rect.height > 0 {
            let linePath = titleBlockLinePath(rect: rect)
            let textPath = titleBlockTextPath(rect: rect)
            CKGroup {
                CKPath(path: linePath).stroke(lineColor.cgColor, width: 1.0)
                CKPath(path: textPath).fill(textColor.cgColor)
            }
        } else {
            CKEmpty()
        }
    }

    private func titleBlockLinePath(rect: CGRect) -> CGPath {
        let linePath = CGMutablePath()
        linePath.addRect(rect)
        for i in 1..<cellValues.count {
            let y = rect.minY + CGFloat(i) * cellHeight
            linePath.move(to: CGPoint(x: rect.minX, y: y))
            linePath.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return linePath
    }

    private func titleBlockTextPath(rect: CGRect) -> CGPath {
        let keyFont = safeFont(8, .semibold)
        let valueFont = safeFont(11, .regular)
        let textPath = CGMutablePath()

        for (row, (key, value)) in cellValues.enumerated() {
            let y = rect.minY + CGFloat(row) * cellHeight
            let cellRect = CGRect(
                x: rect.minX,
                y: y,
                width: rect.width,
                height: cellHeight
            )
            .insetBy(dx: cellPad, dy: 0)

            let keyPath = CKText.path(for: key.uppercased(), font: keyFont)
            let keyPosition = CGPoint(x: cellRect.minX, y: cellRect.midY + 2)
            let keyTransform = CGAffineTransform(
                translationX: keyPosition.x - keyPath.boundingBoxOfPath.minX,
                y: keyPosition.y - keyPath.boundingBoxOfPath.minY
            )
            textPath.addPath(keyPath, transform: keyTransform)

            let valuePath = CKText.path(for: value, font: valueFont)
            let valueBounds = valuePath.boundingBoxOfPath
            let valuePosition = CGPoint(
                x: cellRect.maxX - valueBounds.width,
                y: cellRect.minY + (cellRect.height - valueBounds.height) / 2
            )
            let valueTransform = CGAffineTransform(
                translationX: valuePosition.x - valueBounds.minX,
                y: valuePosition.y - valueBounds.minY
            )
            textPath.addPath(valuePath, transform: valueTransform)
        }

        return textPath
    }
}
