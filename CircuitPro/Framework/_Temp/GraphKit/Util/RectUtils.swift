//
//  RectUtils.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation
import CoreGraphics

enum RectUtils {
    static func aabb(around ids: Set<UUID>, in state: GraphState, padding: CGFloat = 0) -> CGRect {
        var rect: CGRect?
        // Prefer epicenter vertices; if empty, fall back to all vertices
        let points: [CGPoint]
        if ids.isEmpty {
            points = Array(state.vertices.values.map { $0.point })
        } else {
            points = ids.compactMap { state.vertices[$0]?.point }
        }
        for p in points {
            let r = CGRect(x: p.x, y: p.y, width: 0, height: 0)
            rect = rect.map { $0.union(r) } ?? r
        }
        guard var aabb = rect else { return .null }
        if padding > 0 {
            aabb = aabb.insetBy(dx: -padding, dy: -padding)
        }
        return aabb
    }
}
