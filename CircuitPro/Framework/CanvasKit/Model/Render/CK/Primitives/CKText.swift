import AppKit
import CoreText
import SwiftUI

struct CKText: CKView {
    let content: String
    let font: NSFont
    let anchor: TextAnchor

    init(_ content: String, font: NSFont, anchor: TextAnchor = .center) {
        self.content = content
        self.font = font
        self.anchor = anchor
    }

    static func path(for string: String, font: NSFont) -> CGPath {
        let attrString = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attrString)
        let composite = CGMutablePath()

        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return composite }

        for run in runs {
            let runFont = unsafeBitCast(
                CFDictionaryGetValue(
                    CTRunGetAttributes(run),
                    Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()
                ),
                to: CTFont.self
            )

            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)

            CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, count), &positions)

            for i in 0..<count {
                if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                    let transform = CGAffineTransform(
                        translationX: positions[i].x,
                        y: positions[i].y
                    )
                    composite.addPath(glyphPath, transform: transform)
                }
            }
        }

        return composite
    }

    static func bounds(for string: String, font: NSFont) -> CGRect {
        let attrString = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attrString)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        return CGRect(x: 0, y: -descent, width: width, height: ascent + descent + leading)
    }

    static func localBounds(for string: String, font: NSFont, anchor: TextAnchor) -> CGRect {
        let bounds = self.bounds(for: string, font: font)
        let anchorPoint = anchor.point(in: bounds)
        return bounds.offsetBy(dx: -anchorPoint.x, dy: -anchorPoint.y)
    }

    static func worldBounds(
        for string: String,
        font: NSFont,
        anchor: TextAnchor,
        position: CGPoint,
        rotation: CGFloat
    ) -> CGRect {
        let local = localBounds(for: string, font: font, anchor: anchor)
        let corners = [
            CGPoint(x: local.minX, y: local.minY),
            CGPoint(x: local.minX, y: local.maxY),
            CGPoint(x: local.maxX, y: local.minY),
            CGPoint(x: local.maxX, y: local.maxY)
        ]
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
        if rotation != 0 {
            transform = transform.rotated(by: rotation)
        }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for corner in corners {
            let point = corner.applying(transform)
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else {
            return .null
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func worldPath(
        for string: String,
        font: NSFont,
        anchor: TextAnchor,
        position: CGPoint,
        rotation: CGFloat
    ) -> CGPath {
        let textPath = CKText.path(for: string, font: font)
        guard !textPath.isEmpty else { return textPath }
        let bounds = CKText.bounds(for: string, font: font)
        let anchorPoint = anchor.point(in: bounds)
        var transform = CGAffineTransform(
            translationX: position.x - anchorPoint.x,
            y: position.y - anchorPoint.y
        )
        var positioned = textPath.copy(using: &transform) ?? textPath
        if rotation != 0 {
            var rotationTransform = CGAffineTransform(
                translationX: position.x,
                y: position.y
            )
            .rotated(by: rotation)
            .translatedBy(x: -position.x, y: -position.y)
            positioned = positioned.copy(using: &rotationTransform) ?? positioned
        }
        return positioned
    }

    static func hitRectPath(
        for string: String,
        font: NSFont,
        anchor: TextAnchor,
        position: CGPoint,
        rotation: CGFloat
    ) -> CGPath {
        let localBounds = CKText.localBounds(for: string, font: font, anchor: anchor)
        return hitRectPath(localBounds: localBounds, position: position, rotation: rotation)
    }

    static func hitRectPath(
        localBounds: CGRect,
        position: CGPoint,
        rotation: CGFloat
    ) -> CGPath {
        let rectPath = CGPath(rect: localBounds, transform: nil)
        var translation = CGAffineTransform(translationX: position.x, y: position.y)
        var positioned = rectPath.copy(using: &translation) ?? rectPath
        if rotation != 0 {
            var rotationTransform = CGAffineTransform(
                translationX: position.x,
                y: position.y
            )
            .rotated(by: rotation)
            .translatedBy(x: -position.x, y: -position.y)
            positioned = positioned.copy(using: &rotationTransform) ?? positioned
        }
        return positioned
    }

}

extension CKText: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        CKRenderNode(
            geometry: .path { _ in
                let textPath = CKText.path(for: content, font: font)
                guard !textPath.isEmpty else { return CGMutablePath() }
                let bounds = CKText.bounds(for: content, font: font)
                let anchorPoint = anchor.point(in: bounds)
                let transform = CGAffineTransform(
                    translationX: -anchorPoint.x,
                    y: -anchorPoint.y
                )
                let finalPath = CGMutablePath()
                finalPath.addPath(textPath, transform: transform)
                return finalPath
            }
        )
    }
}
