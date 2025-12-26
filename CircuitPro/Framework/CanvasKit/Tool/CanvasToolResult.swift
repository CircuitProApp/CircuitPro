//
//  CanvasToolResult.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 17.07.25.
//

import Foundation

enum CanvasToolResult: Equatable {
    case noResult
    case newNode(BaseNode)
    case newPrimitive(AnyCanvasPrimitive)
}
