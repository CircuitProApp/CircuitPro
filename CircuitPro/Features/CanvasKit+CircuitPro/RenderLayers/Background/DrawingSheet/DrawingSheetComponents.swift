//
//  DrawingSheetComponents.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import AppKit

// MARK: - DrawingMetrics
struct DrawingMetrics {
    let outerBounds: CGRect
    let innerBounds: CGRect
    let titleBlockFrame: CGRect
    let horizontalTickSpacing: CGFloat
    let verticalTickSpacing: CGFloat

    init(viewBounds: CGRect, inset: CGFloat, horizontalTickSpacing: CGFloat, verticalTickSpacing: CGFloat, cellHeight: CGFloat, cellValues: [String: String]) {
        // Correct: outerBounds must match the view's true bounds for background fills.
        self.outerBounds = viewBounds
        self.innerBounds = outerBounds.insetBy(dx: inset, dy: inset)
        self.horizontalTickSpacing = horizontalTickSpacing
        self.verticalTickSpacing = verticalTickSpacing

        let rowCount = cellValues.count
        let blockWidth = cellHeight * 8
        let blockHeight = CGFloat(rowCount) * cellHeight

        self.titleBlockFrame = CGRect(
            x: innerBounds.maxX - blockWidth,
            y: innerBounds.minY,
            width: blockWidth,
            height: blockHeight
        )
    }
}

// MARK: - BorderDrawer
struct BorderDrawer {
    func makeLayers(metrics: DrawingMetrics, lineColor: CGColor) -> [CAShapeLayer] {
        let outerBorder = CAShapeLayer()
        // THE FIX: Inset the path itself by 0.5 points. This ensures that the 1-point
        // stroke is drawn entirely within the layer's bounds, preventing clipping and gaps.
        outerBorder.path = CGPath(rect: metrics.outerBounds.insetBy(dx: 0.5, dy: 0.5), transform: nil)

        let innerBorder = CAShapeLayer()
        innerBorder.path = CGPath(rect: metrics.innerBounds, transform: nil)

        return [outerBorder, innerBorder].map {
            $0.strokeColor = lineColor
            $0.fillColor = nil
            $0.lineWidth = 1.0
            return $0
        }
    }
}

// MARK: - RulerDrawer
struct RulerDrawer {
    enum Position { case top, bottom, left, right }

    let position: Position
    let lineColor: NSColor
    let textColor: NSColor
    let safeFont: (CGFloat, NSFont.Weight) -> NSFont
    let showLabels: Bool

    func makeLayers(metrics: DrawingMetrics) -> [CALayer] {
        let spacing = isVertical() ? metrics.verticalTickSpacing : metrics.horizontalTickSpacing
        guard spacing > 0 else { return [] }

        let tickLayer = makeTicksLayer(metrics: metrics, tickSpacing: spacing)
        var layers: [CALayer] = [tickLayer]

        if showLabels {
            let labelsLayer = makeLabelsLayer(metrics: metrics, tickSpacing: spacing)
            layers.append(labelsLayer)
        }

        return layers
    }

    private func makeTicksLayer(metrics: DrawingMetrics, tickSpacing: CGFloat) -> CAShapeLayer {
        let tickPath = CGMutablePath()
        let inner = metrics.innerBounds
        let outer = metrics.outerBounds

        if isVertical() {
            let xStart = isPrimaryEdge() ? inner.minX : inner.maxX
            let xEnd = isPrimaryEdge() ? outer.minX : outer.maxX
            let yRange = stride(from: inner.maxY - tickSpacing, to: inner.minY, by: -tickSpacing)
            yRange.forEach { y in
                tickPath.move(to: CGPoint(x: xStart, y: y))
                tickPath.addLine(to: CGPoint(x: xEnd, y: y))
            }
        } else { // Horizontal
            let yStart = isPrimaryEdge() ? inner.minY : inner.maxY
            let yEnd = isPrimaryEdge() ? outer.minY : outer.maxY
            let xRange = stride(from: inner.minX + tickSpacing, to: inner.maxX, by: tickSpacing)
            xRange.forEach { x in
                tickPath.move(to: CGPoint(x: x, y: yStart))
                tickPath.addLine(to: CGPoint(x: x, y: yEnd))
            }
        }

        let layer = CAShapeLayer()
        layer.path = tickPath
        layer.strokeColor = lineColor.cgColor
        layer.lineWidth = 1.0
        return layer
    }

    private func makeLabelsLayer(metrics: DrawingMetrics, tickSpacing: CGFloat) -> CAShapeLayer {
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
        } else { // Horizontal
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

        let layer = CAShapeLayer()
        layer.path = path
        layer.fillColor = textColor.cgColor
        return layer
    }

    private func isVertical() -> Bool { position == .left || position == .right }
    private func isPrimaryEdge() -> Bool { position == .top || position == .left }

    private func labelForIndex(_ index: Int, isNumber: Bool) -> String {
        if isNumber { return "\(index + 1)" }
        var number = index, label = ""
        repeat {
            label = String(UnicodeScalar(65 + (number % 26))!) + label
            number = number / 26 - 1
        } while number >= 0
        return label
    }
}

// MARK: - TitleBlockDrawer
struct TitleBlockDrawer {
    let cellValues: [String: String]
    let lineColor: NSColor
    let textColor: NSColor
    let cellPad: CGFloat
    let cellHeight: CGFloat
    let safeFont: (CGFloat, NSFont.Weight) -> NSFont

    func makeLayers(metrics: DrawingMetrics) -> [CALayer] {
        let rect = metrics.titleBlockFrame

        // 1. Create lines layer
        let linePath = CGMutablePath()
        linePath.addRect(rect)
        for i in 1..<cellValues.count {
            let y = rect.minY + CGFloat(i) * cellHeight
            linePath.move(to: CGPoint(x: rect.minX, y: y))
            linePath.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        let lineLayer = CAShapeLayer()
        lineLayer.path = linePath
        lineLayer.strokeColor = lineColor.cgColor
        lineLayer.fillColor = nil
        lineLayer.lineWidth = 1.0

        var layers: [CALayer] = [lineLayer]

        // 2. Create text layers
        let keyFont = safeFont(8, .semibold)
        let valueFont = safeFont(11, .regular)

        for (row, (key, value)) in cellValues.enumerated() {
            let y = rect.minY + CGFloat(row) * cellHeight
            let cellRect = CGRect(x: rect.minX, y: y, width: rect.width, height: cellHeight).insetBy(dx: cellPad, dy: 0)

            // Key
            let keyPath = CKText.path(for: key.uppercased(), font: keyFont)
            let keyPosition = CGPoint(x: cellRect.minX, y: cellRect.midY + 2)
            var keyTransform = CGAffineTransform(translationX: keyPosition.x - keyPath.boundingBoxOfPath.minX, y: keyPosition.y - keyPath.boundingBoxOfPath.minY)

            let keyLayer = CAShapeLayer()
            keyLayer.path = keyPath.copy(using: &keyTransform)
            keyLayer.fillColor = textColor.cgColor
            layers.append(keyLayer)

            // Value
            let valuePath = CKText.path(for: value, font: valueFont)
            let valueBounds = valuePath.boundingBoxOfPath
            let valuePosition = CGPoint(x: cellRect.maxX - valueBounds.width, y: cellRect.minY + (cellRect.height - valueBounds.height) / 2)
            var valueTransform = CGAffineTransform(translationX: valuePosition.x - valueBounds.minX, y: valuePosition.y - valueBounds.minY)

            let valueLayer = CAShapeLayer()
            valueLayer.path = valuePath.copy(using: &valueTransform)
            valueLayer.fillColor = textColor.cgColor
            layers.append(valueLayer)
        }

        return layers
    }
}
