//
//  CanvasDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import AppKit

protocol CanvasDragGesture {
    func begin(at point: CGPoint, event: NSEvent) -> Bool
    func drag (to point: CGPoint)
    func end()
}
