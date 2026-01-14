//
//  CanvasPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import CoreGraphics
import Foundation

protocol CanvasPrimitive: Transformable, Identifiable, Codable, Equatable, Hashable, Layerable {

    var id: UUID { get }
    var layerId: UUID? { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool { get set }
}
