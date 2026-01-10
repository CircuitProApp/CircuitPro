import AppKit
import CoreText

struct CKText: CKShape {
    let content: String
    let font: NSFont
    var style: CKStyle = .init()

    init(_ content: String, font: NSFont) {
        self.content = content
        self.font = font
        self.style.fillColor = NSColor.labelColor.cgColor
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

    func shapePath() -> CGPath {
        let textPath = CKText.path(for: content, font: font)
        guard !textPath.isEmpty else { return CGMutablePath() }
        let bounds = textPath.boundingBoxOfPath
        let position = style.position ?? .zero
        let transform = CGAffineTransform(
            translationX: position.x - bounds.midX,
            y: position.y - bounds.midY
        )
        let finalPath = CGMutablePath()
        finalPath.addPath(textPath, transform: transform)
        return finalPath
    }
}
