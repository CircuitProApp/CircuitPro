//
//  ComponentInstance+CanvasDrawing.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import AppKit

extension ComponentInstance: Transformable {

    var position: CGPoint {
        get { symbolInstance.position }
        set { symbolInstance.position = newValue }
    }

    var rotation: CGFloat {
        get { symbolInstance.rotation }
        set { symbolInstance.rotation = newValue }
    }

}
