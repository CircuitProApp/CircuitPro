//
//  Pad+Bounded.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/23/25.
//

import AppKit

extension Pad: Bounded {
    /// The bounding box should still encompass the original primitives.
    var boundingBox: CGRect {
        return allPrimitives
            .map(\.boundingBox)
            .reduce(CGRect.null) { $0.union($1) }
    }
}
