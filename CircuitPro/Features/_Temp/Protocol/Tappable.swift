//
//  Tappable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.06.25.
//

import SwiftUI

protocol Tappable {
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool
}
