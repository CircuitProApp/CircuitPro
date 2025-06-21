//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

protocol GraphicPrimitive: Identifiable, Hashable, Codable {

    var id: UUID { get }
    var position: CGPoint { get set }
    var rotation: CGFloat { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool { get set }

}
