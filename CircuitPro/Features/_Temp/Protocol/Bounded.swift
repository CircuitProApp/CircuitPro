//
//  Bounded.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 23.06.25.
//

import SwiftUI

/// Anything that can report a conservative axis-aligned bounding box
/// in the canvas’ coordinate system.
protocol Bounded {
    var boundingBox: CGRect { get }
}
