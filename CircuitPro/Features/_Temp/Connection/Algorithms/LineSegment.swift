//
//  LineSegment.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import Foundation
import CoreGraphics

struct LineSegment {

    var start: CGPoint
    var end: CGPoint
    var isHorizontal: Bool { start.y == end.y }
    var isVertical: Bool { start.x == end.x }

    func intersectionPoint(with other: LineSegment) -> CGPoint? {
        if isHorizontal && other.isVertical {
            if start.y.isBetween(other.start.y, other.end.y) &&
                other.start.x.isBetween(start.x, end.x) {
                return CGPoint(x: other.start.x, y: start.y)
            }
        } else if isVertical && other.isHorizontal {
            if start.x.isBetween(other.start.x, other.end.x) &&
                other.start.y.isBetween(start.y, end.y) {
                return CGPoint(x: start.x, y: other.start.y)
            }
        }
        return nil
    }
}
