//
//  Helpers.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

// Any primitive ---------------------------------------------------------
extension AnyPrimitive {
    func shifted(by delta: CGPoint) -> AnyPrimitive {
        switch self {
        case .rectangle(var r):
            r.position.x -= delta.x
            r.position.y -= delta.y
            return .rectangle(r)
        case .circle(var c):
            c.position.x -= delta.x
            c.position.y -= delta.y
            return .circle(c)
        case .line(var l):
            l.start.x -= delta.x; l.start.y -= delta.y
            l.end.x   -= delta.x; l.end.y   -= delta.y
            return .line(l)
        }
    }
}

// Pin --------------------------------------------------------------------
extension Pin {
    func shifted(by delta: CGPoint) -> Pin {
        var p = self
        p.position.x -= delta.x
        p.position.y -= delta.y
        return p
    }
}
