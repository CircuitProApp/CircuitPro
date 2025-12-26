//
//  GraphPadComponent.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics
import Foundation

struct GraphPadComponent: GraphComponent {
    var pad: Pad
    var ownerID: UUID?
    var ownerPosition: CGPoint
    var ownerRotation: CGFloat
    var layerId: UUID?
    var isSelectable: Bool
}

extension GraphPadComponent {
    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
            .rotated(by: ownerRotation)
    }

    var worldTransform: CGAffineTransform {
        CGAffineTransform(translationX: pad.position.x, y: pad.position.y)
            .rotated(by: pad.rotation)
            .concatenating(ownerTransform)
    }
}
