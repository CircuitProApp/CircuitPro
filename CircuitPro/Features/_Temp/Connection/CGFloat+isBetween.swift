//
//  CGFloat+isBetween.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import CoreGraphics
import Foundation

extension CGFloat {
    func isBetween(_ lowerBound: CGFloat, _ upperBound: CGFloat) -> Bool {
        (Swift.min(lowerBound, upperBound)...Swift.max(lowerBound, upperBound)).contains(self)
    }
}
