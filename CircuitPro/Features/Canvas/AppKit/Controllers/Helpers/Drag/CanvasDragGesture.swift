//
//  CanvasDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import AppKit

protocol CanvasDragGesture {
    func drag (to point: CGPoint)
    func end()
}
