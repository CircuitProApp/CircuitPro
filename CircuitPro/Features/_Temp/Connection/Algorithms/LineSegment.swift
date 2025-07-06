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
    var isVertical:   Bool { start.x == end.x }

    func intersectionPoint(with o: LineSegment) -> CGPoint? {
        if isHorizontal && o.isVertical {
            if start.y.isBetween(o.start.y, o.end.y) &&
               o.start.x.isBetween(start.x, end.x) {
                return CGPoint(x: o.start.x, y: start.y)
            }
        } else if isVertical && o.isHorizontal {
            if start.x.isBetween(o.start.x, o.end.x) &&
               o.start.y.isBetween(start.y, end.y) {
                return CGPoint(x: start.x, y: o.start.y)
            }
        }
        return nil
    }
}
