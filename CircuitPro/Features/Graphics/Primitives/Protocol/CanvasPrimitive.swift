//
//  CanvasPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import SwiftUI

protocol CanvasPrimitive {

    var color: SDColor { get set }
    
    func makePath(offset: CGPoint) -> CGPath

    func handles() -> [Handle]

    mutating func updateHandle(_ kind: Handle.Kind, to position: CGPoint, opposite frozenOpposite: CGPoint?)

}

extension CanvasPrimitive {
    mutating func updateHandle(_ kind: Handle.Kind, to position: CGPoint) {
        updateHandle(kind, to: position, opposite: nil)
    }
}
