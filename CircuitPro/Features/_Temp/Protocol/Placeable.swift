//
//  Placeable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.06.25.
//

import SwiftUI

protocol Placeable {
    var position: CGPoint { get set }
    var rotation: CGFloat { get set }

    mutating func translate(by delta: CGPoint)
    mutating func rotate(by angle: CGFloat, around pivot: CGPoint)
}

extension Placeable {
    mutating func translate(by delta: CGPoint) {
        position += delta
    }

    mutating func rotate(by angle: CGFloat, around pivot: CGPoint = .zero) {
        let deltaX = position.x - pivot.x
        let deltaY = position.y - pivot.y
        let sin  = sin(angle)
        let cos  = cos(angle)
        position.x = pivot.x + deltaX * cos - deltaY * sin
        position.y = pivot.y + deltaX * sin + deltaY * cos
        rotation += angle
    }
}
