//
//  DraggableTransferable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

// A new protocol that combines the necessary conformances and
// requires the type to declare its own content type.
protocol DraggableTransferable: Transferable, Codable {
    static var dragContentType: UTType { get }
}
