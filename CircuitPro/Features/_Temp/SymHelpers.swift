//
//  Helpers.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

// Pin --------------------------------------------------------------------
extension Pin {
    func shifted(by delta: CGPoint) -> Pin {
        var p = self
        p.position.x -= delta.x
        p.position.y -= delta.y
        return p
    }
}
