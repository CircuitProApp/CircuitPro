//
//  Pin+Bounded.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

extension Pin: Bounded {
    var boundingBox: CGRect {
        var box = primitives
            .map(\.boundingBox)
            .reduce(CGRect.null) { $0.union($1) }

        if showLabel && name.isNotEmpty {
            let (text, pos, font) = labelLayout()
            box = box.union(textRect(text, font: font, at: pos))
        }
        if showNumber {
            let (text, pos, font) = numberLayout()
            box = box.union(textRect(text, font: font, at: pos))
        }
        return box
    }

    private func textRect(
        _ string: String,
        font: NSFont,
        at origin: CGPoint
    ) -> CGRect {
        let size = (string as NSString).size(withAttributes: [.font: font])

        return CGRect(origin: origin, size: size)
    }
}
