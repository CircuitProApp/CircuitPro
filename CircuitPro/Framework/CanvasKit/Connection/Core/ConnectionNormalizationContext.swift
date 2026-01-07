//
//  ConnectionNormalizationContext.swift
//  CircuitPro
//
//  Created by Codex on 1/4/26.
//

import CoreGraphics
import Foundation

struct ConnectionNormalizationContext {
    let magnification: CGFloat
    let snapPoint: (CGPoint) -> CGPoint

    init(
        magnification: CGFloat = 1,
        snapPoint: @escaping (CGPoint) -> CGPoint = { $0 }
    ) {
        self.magnification = magnification
        self.snapPoint = snapPoint
    }
}
