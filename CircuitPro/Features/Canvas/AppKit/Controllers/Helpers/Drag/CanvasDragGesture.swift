//
//  CanvasDragGesture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import AppKit

protocol CanvasDragGesture {
    func begin(at p: CGPoint, event: NSEvent) -> Bool   // returns true if it claimed the drag
    func drag (to p: CGPoint)
    func end()
}
