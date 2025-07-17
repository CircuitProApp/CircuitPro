//
//  CanvasToolResult.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 17.07.25.
//

import Foundation

enum CanvasToolResult {
    case element(CanvasElement)
    case connection(ConnectionElement)
    case noResult
}
