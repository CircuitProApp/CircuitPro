// Pin+Rendering.swift
import AppKit

private let haloThickness: CGFloat = 4 // keep all magic numbers in one place

extension Pin {

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func draw(
        in ctx: CGContext,
        showText: Bool = true,
        highlight: Bool = false
    ) {
        // 2. world-space geometry
        let legStart = CGPoint(
            x: position.x + dir.x * length,
            y: position.y + dir.y * length
        )
        let legMid = CGPoint(
            x: (legStart.x + position.x) / 2,
            y: (legStart.y + position.y) / 2
        )
        // ───────────────────────────────────────────── 1. primitives
        for prim in primitives {
            prim.draw(in: ctx, selected: false)
        }

        // ───────────────────────────────────────────── 2. unified halo
        if highlight {
            let haloPath = CGMutablePath()
            for prim in primitives {
                let stroked = prim.makePath()
                    .copy(
                        strokingWithWidth: haloThickness,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 10
                    )
                haloPath.addPath(stroked)
            }
            ctx.saveGState()
            ctx.addPath(haloPath)
            ctx.setFillColor(NSColor(.blue.opacity(0.4)).cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }

        // ───────────────────────────────────────────── 3. text
        guard showText else { return }
        let font = NSFont.systemFont(ofSize: 10)
        let numString = "\(number)"
        let numW = numString.size(withAttributes: [.font: font]).width

        // number always horizontal
        let numOff: CGPoint = {
            switch rotation {
            case .deg0:
                return CGPoint(x: -numW/2, y: -font.pointSize - 3)
            case .deg90:
                return CGPoint(x: 3, y: -font.pointSize/2)
            case .deg180:
                return CGPoint(x: -numW/2, y: 3)
            case .deg270:
                return CGPoint(x: -numW - 3, y: -font.pointSize/2)
            }
        }()

        if showNumber {
            let pos = CGPoint(
                x: legMid.x + numOff.x,
                y: legMid.y + numOff.y
            )
            drawAttributedText(
                numString,
                font: font,
                color: .systemBlue,
                isSelected: highlight,
                at: pos,
                context: ctx
            )
        }

        // label
        if showLabel && !name.isEmpty {
            // draw aligned with leg for vertical, horizontal for left/right
            ctx.saveGState()
            switch rotation {
            case .deg0, .deg180:
                // horizontal labels
                let lblW = name.size(withAttributes: [.font: font]).width
                let lblOffX: CGFloat = (rotation == .deg0)
                    ? -length - 6 - lblW
                    :  length + 6
                let lblOffY: CGFloat = -font.pointSize/2
                let pos = CGPoint(x: position.x + lblOffX, y: position.y + lblOffY)
                drawAttributedText(
                    name,
                    font: font,
                    color: .systemBlue,
                    isSelected: highlight,
                    at: pos,
                    context: ctx
                )

            case .deg90:
                // vertical up: rotate CCW, draw at legStart
                let pos = legStart
                ctx.translateBy(x: pos.x, y: pos.y)
                ctx.rotate(by: .pi/2)
                // after rotate, draw text offset along y
                drawAttributedText(
                    name,
                    font: font,
                    color: .systemBlue,
                    isSelected: highlight,
                    at: CGPoint(x: -font.pointSize/2, y: 6),
                    context: ctx
                )

            case .deg270:
                // vertical down: rotate CW, draw at legStart
                let pos = legStart
                ctx.translateBy(x: pos.x, y: pos.y)
                ctx.rotate(by: -.pi/2)
                drawAttributedText(
                    name,
                    font: font,
                    color: .systemBlue,
                    isSelected: highlight,
                    at: CGPoint(x: font.pointSize/2, y: -6),
                    context: ctx
                )
            }
            ctx.restoreGState()
        }
    }
}

// MARK: - Tiny helper used for both number & label
// swiftlint:disable:next function_parameter_count
private func drawAttributedText(
    _ string: String,
    font: NSFont,
    color: NSColor,
    isSelected: Bool,
    at origin: CGPoint,
    context ctx: CGContext
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    if isSelected {
        attrs[.strokeColor] = NSColor(.blue.opacity(0.4)).cgColor
        attrs[.strokeWidth] = -10 // negative → stroke *and* fill
    }
    let str = NSAttributedString(string: string, attributes: attrs)
    ctx.saveGState()
    str.draw(at: origin)
    ctx.restoreGState()
}

extension Pin {

    // swiftlint:disable:next function_body_length
    func textHitRects(font: NSFont = .systemFont(ofSize: 10)) -> (number: CGRect?, label: CGRect?) {
        let legStart = CGPoint(
            x: position.x + dir.x * length,
            y: position.y + dir.y * length
        )
        let legMid = CGPoint(
            x: (legStart.x + position.x) / 2,
            y: (legStart.y + position.y) / 2
        )
        var numberRect: CGRect?
        var labelRect: CGRect?

        // ── Number hit‐rect ────────────────────────────────────────────────
        if showNumber {
            let numString = "\(number)"
            let numSize = numString.size(withAttributes: [.font: font])

            // exactly the same offset logic you use in draw(in:)
            let numOff: CGPoint = {
                switch rotation {
                case .deg0:
                    return CGPoint(x: -numSize.width/2, y: -font.pointSize - 3)
                case .deg90:
                    return CGPoint(x: 3, y: -numSize.height/2)
                case .deg180:
                    return CGPoint(x: -numSize.width/2, y: 3)
                case .deg270:
                    return CGPoint(x: -numSize.width - 3, y: -numSize.height/2)
                }
            }()

            let origin = CGPoint(
                x: legMid.x + numOff.x,
                y: legMid.y + numOff.y
            )
            numberRect = CGRect(origin: origin, size: numSize)
        }

        // ── Label hit‐rect ─────────────────────────────────────────────────
        if showLabel, !name.isEmpty {
            let lblSize = name.size(withAttributes: [.font: font])

            switch rotation {
            case .deg0, .deg180:
                // horizontal labels
                let lblOffX: CGFloat = (rotation == .deg0)
                    ? -length - 6 - lblSize.width
                    :   length + 6
                let lblOffY: CGFloat = -font.pointSize / 2

                let origin = CGPoint(
                    x: position.x + lblOffX,
                    y: position.y + lblOffY
                )
                labelRect = CGRect(origin: origin, size: lblSize)

            case .deg90, .deg270:
                // vertical labels: draw at legStart, then rotate
                let pos = legStart
                // the same per-axis offset you use when drawing
                let localOffset = (rotation == .deg90)
                    ? CGPoint(x: -font.pointSize/2, y: 6)
                    : CGPoint(x: font.pointSize/2, y: -6)

                // build a local rect at that offset
                let unrotatedRect = CGRect(origin: localOffset, size: lblSize)

                // apply translate → rotate exactly as in draw(in:)
                var transform = CGAffineTransform(translationX: pos.x, y: pos.y)
                transform = transform.rotated(by: (rotation == .deg90) ? .pi/2 : -.pi/2)

                // transform and take bounding box
                if let transformed = CGPath(rect: unrotatedRect, transform: nil)
                                    .copy(using: &transform) {
                    labelRect = transformed.boundingBox
                }
            }
        }

        return (numberRect, labelRect)
    }
}
