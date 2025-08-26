//
//  GridPolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

public protocol GridPolicy {
    var step: CGFloat { get }
    var epsilon: CGFloat { get }
    func snap(_ p: CGPoint) -> CGPoint
    func isHorizontal(_ a: CGPoint, _ b: CGPoint) -> Bool
    func isVertical(_ a: CGPoint, _ b: CGPoint) -> Bool
}


