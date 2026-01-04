//
//  CanvasLayer.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/8/25.
//

import CoreGraphics
import Foundation

/// A lightweight layer contract that CanvasKit can render against.
protocol CanvasLayer: Identifiable where ID == UUID {
    var name: String { get }
    var isVisible: Bool { get }
    var color: CGColor { get }
    var zIndex: Int { get }
}
