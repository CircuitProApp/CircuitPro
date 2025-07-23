//
//  TextUtilities.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit
import CoreText

// MARK: - TextUtilities
enum TextUtilities {
    /// Generates a CGPath for a given string and font, positioned at the origin (0,0).
    /// - Parameters:
    ///   - string: The text to convert.
    ///   - font: The font to use for rendering the text.
    /// - Returns: A `CGPath` representing the vector outline of the string.
    static func path(for string: String, font: NSFont) -> CGPath {
        let attrString = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attrString)
        let composite = CGMutablePath()

        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return composite }

        for run in runs {
            // Get font from the run
            let runFont = unsafeBitCast(
                CFDictionaryGetValue(CTRunGetAttributes(run),
                Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()),
                to: CTFont.self
            )

            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)

            CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, count), &positions)
            
            // For each glyph, create a path and add it to the composite path
            for i in 0..<count {
                if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                    let transform = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                    composite.addPath(glyphPath, transform: transform)
                }
            }
        }
        return composite
    }
}
