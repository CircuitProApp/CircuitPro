//
//  Pin+Drawable.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import AppKit

extension Pin: Drawable {

    func drawBody(in ctx: CGContext) {
        // draw the leg & pad but *without* the default halo
        primitives.forEach { $0.drawBody(in: ctx) }

        if showNumber {
            drawNumber(in: ctx)
        }

        if showLabel && name.isNotEmpty {
            drawLabel(in: ctx)
        }
    }
    
    func makeHaloParameters() -> DrawingParameters? {
        nil
    }

    private func drawLabel(in ctx: CGContext) {

        let text  = label as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.systemBlue
        ]
        let size = text.size(withAttributes: attrs)
        let pad: CGFloat = 4

        // put the label a little further out than legStart
        let pos: CGPoint
        switch cardinalRotation {
        case .deg0:    // pointing right
            pos = CGPoint(x: legStart.x + pad, y: legStart.y - size.height / 2)
        case .deg180:  // pointing left
            pos = CGPoint(x: position.x - length - pad - size.width, y: legStart.y - size.height / 2)
        case .deg90:   // pointing down
            pos = CGPoint(x: position.x - size.width / 2, y: legStart.y + pad)
        case .deg270:  // pointing up
            pos = CGPoint(x: position.x - size.width / 2, y: position.y - length - pad - size.height)
        }

        text.draw(at: pos, withAttributes: attrs)
    }

    private func drawNumber(in ctx: CGContext) {

        let text  = "\(number)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.systemBlue
        ]
        let size = text.size(withAttributes: attrs)
        let pad: CGFloat = 3

        // midpoint of the leg
        let mid = CGPoint(x: (position.x + legStart.x) / 2, y: (position.y + legStart.y) / 2)

        // place the number perpendicular to the leg, on the “above” side
        let pos: CGPoint
        switch cardinalRotation {
        case .deg0:    // horizontal → above = up (negative y)
            pos = CGPoint(x: mid.x - size.width / 2, y: mid.y - pad - size.height)
        case .deg180:  // horizontal → above = up
            pos = CGPoint(x: mid.x - size.width / 2, y: mid.y - pad - size.height)
        case .deg90:   // vertical down → above = left
            pos = CGPoint(x: mid.x - pad - size.width, y: mid.y - size.height / 2)
        case .deg270:  // vertical up → above = right
            pos = CGPoint(x: mid.x + pad, y: mid.y - size.height / 2)
        }

        text.draw(at: pos, withAttributes: attrs)
    }

    func selectionPath() -> CGPath? {

        let outline = CGMutablePath()

        // 1. leg + pad
        primitives.forEach { outline.addPath($0.makePath()) }

        // 2. label glyphs
        if showLabel && name.isNotEmpty {
            let (text, pos, font) = labelLayout()
            outline.addPath(pathForText(text, font: font, at: pos))
        }

        // 3. number glyphs
        if showNumber {
            let (text, pos, font) = numberLayout()
            outline.addPath(pathForText(text, font: font, at: pos))
        }

        return outline
    }

    // ─────────────────────────── same positioning logic as drawBody(in:)
    func labelLayout() -> (String, CGPoint, NSFont) {
        let font = NSFont.systemFont(ofSize: 10)
        let pad: CGFloat = 4
        let size = (label as NSString).size(withAttributes: [.font: font])

        switch cardinalRotation {
        case .deg0:
            return (label,
                    CGPoint(x: legStart.x + pad, y: legStart.y - size.height / 2),
                    font)

        case .deg180:
            return (label,
                    CGPoint(x: position.x - length - pad - size.width, y: legStart.y - size.height / 2),
                    font)

        case .deg90:
            return (label,
                    CGPoint(x: position.x - size.width / 2, y: legStart.y + pad),
                    font)

        case .deg270:
            return (label,
                    CGPoint(x: position.x - size.width / 2, y: position.y - length - pad - size.height),
                    font)
        }
    }

    func numberLayout() -> (String, CGPoint, NSFont) {
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let pad: CGFloat = 3
        let text = "\(number)"
        let size = (text as NSString).size(withAttributes: [.font: font])

        let mid = CGPoint(x: (position.x + legStart.x) / 2, y: (position.y + legStart.y) / 2)

        switch cardinalRotation {
        case .deg0, .deg180:
            return (text,
                    CGPoint(x: mid.x - size.width / 2, y: mid.y - pad - size.height),
                    font)

        case .deg90:
            return (text,
                    CGPoint(x: mid.x - pad - size.width, y: mid.y - size.height / 2),
                    font)

        case .deg270:
            return (text,
                    CGPoint(x: mid.x + pad, y: mid.y - size.height / 2),
                    font)
        }
    }
}

import CoreText

/// Exact glyph outlines for `string`, positioned in the *flipped*
/// world space used by `NSView(isFlipped == true)`.
private func pathForText(
    _ string: String,
    font: NSFont,
    at origin: CGPoint
) -> CGPath {
    // 1. Lay the string out once with Core Text
    let attrString = NSAttributedString(string: string, attributes: [.font: font])
    let line       = CTLineCreateWithAttributedString(attrString)

    let composite  = CGMutablePath()

    // 2. Iterate over the glyph runs of that line
    // swiftlint:disable:next force_cast
    for run in (CTLineGetGlyphRuns(line) as! [CTRun]) {

        let runFont = unsafeBitCast(
            CFDictionaryGetValue(CTRunGetAttributes(run), Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()),
            to: CTFont.self
        )

        let count = CTRunGetGlyphCount(run)

        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, 0), &positions)

        let ascender = CGFloat(CTFontGetAscent(runFont))

        // 3. Copy every glyph path, mirrored and translated
        for i in 0..<count {
            guard let gPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil)
            else { continue }

            // a) move to glyph position relative to requested origin
            // b) move down by the font’s ascender (baseline → flipped space)
            // c) mirror the y-axis (scale y by −1)
            var transform = CGAffineTransform(
                translationX: origin.x + positions[i].x,
                y: origin.y + positions[i].y + ascender
            )

            transform = transform.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: -0.3)

            composite.addPath(gPath, transform: transform)
        }
    }

    return composite
}
