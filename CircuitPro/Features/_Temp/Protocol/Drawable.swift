//
//  Drawable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.06.25.
//

import SwiftUI

protocol Drawable {
    func draw(in ctx: CGContext, selected: Bool)
}
