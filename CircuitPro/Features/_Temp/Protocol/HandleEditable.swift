//
//  HandleEditable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.06.25.
//

import SwiftUI

protocol HandleEditable {
    func handles() -> [Handle]

    mutating func updateHandle(_ kind: Handle.Kind, to position: CGPoint, opposite frozenOpposite: CGPoint?)
}

extension HandleEditable {
    mutating func updateHandle(_ kind: Handle.Kind, to position: CGPoint) {
        updateHandle(kind, to: position, opposite: nil)
    }
}
