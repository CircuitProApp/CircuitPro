//
//  Transformable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.06.25.
//

import SwiftUI

protocol Transformable {
    var position: CGPoint { get set }
    var rotation: CGFloat { get set }
}

extension Transformable {          // default implementation
    mutating func translate(by v: CGVector) {
        position.x += v.dx
        position.y += v.dy
    }
}
