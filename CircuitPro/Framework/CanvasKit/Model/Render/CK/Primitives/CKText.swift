import AppKit
import CoreText
import SwiftUI

struct CKText: CKPathView {
    let content: String
    let font: NSFont
    let anchor: TextAnchor

    init(_ content: String, font: NSFont, anchor: TextAnchor = .center) {
        self.content = content
        self.font = font
        self.anchor = anchor
    }

    var defaultStyle: CKStyle {
        var style = CKStyle()
        style.fillColor = NSColor.labelColor.cgColor
        return style
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

    func path(in context: RenderContext, style: CKStyle) -> CGPath {
        let textPath = CKText.path(for: content, font: font)
        guard !textPath.isEmpty else { return CGMutablePath() }
        let bounds = CKText.bounds(for: content, font: font)
        let position = style.position ?? .zero
        let anchorPoint = anchor.point(in: bounds)
        let transform = CGAffineTransform(
            translationX: position.x - anchorPoint.x,
            y: position.y - anchorPoint.y
        )
        let finalPath = CGMutablePath()
        finalPath.addPath(textPath, transform: transform)
        return finalPath
    }
}
