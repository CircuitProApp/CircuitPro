//
//  CGFloat+isBetween.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import CoreGraphics
import Foundation

extension CGFloat {
    func isBetween(_ a: CGFloat, _ b: CGFloat) -> Bool {
        (Swift.min(a, b)...Swift.max(a, b)).contains(self)
    }
}
