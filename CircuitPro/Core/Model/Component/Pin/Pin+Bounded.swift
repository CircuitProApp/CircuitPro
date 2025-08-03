//
//  Pin+Bounded.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

extension Pin: Bounded {
    var boundingBox: CGRect {
        // 1. Start with the bounding box of the geometric primitives.
        var box = primitives
            .map(\.boundingBox)
            .reduce(CGRect.null) { $0.union($1) }

        // 2. Union the bounding box for the pin label.
        if showLabel && name.isNotEmpty {
            var (path, transform) = labelLayout()
            if let finalPath = path.copy(using: &transform) {
                box = box.union(finalPath.boundingBoxOfPath)
            }
        }
        
        // 3. Union the bounding box for the pin number.
        if showNumber {
            var (path, transform) = numberLayout()
            if let finalPath = path.copy(using: &transform) {
                box = box.union(finalPath.boundingBoxOfPath)
            }
        }
        
        return box
    }
}
