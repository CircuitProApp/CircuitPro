//
//  GeometryPolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/27/25.
//

import Foundation

protocol GeometryPolicy {
    var epsilon: CGFloat { get }
    var neighborhoodPadding: CGFloat { get } // used to expand AABB during resolve
    func snap(_ p: CGPoint) -> CGPoint

    // Direction model
    func admissibleDirections() -> [CGVector] // unit vectors, e.g., [ (1,0), (0,1) ] for Manhattan
    func isCollinear(a: CGPoint, b: CGPoint, dir: CGVector) -> Bool
    func projectParam(origin: CGPoint, dir: CGVector, point: CGPoint) -> CGFloat
}
