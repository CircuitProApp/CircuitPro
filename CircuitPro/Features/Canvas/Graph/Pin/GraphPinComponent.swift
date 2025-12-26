//
//  GraphPinComponent.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import CoreGraphics
import Foundation

struct GraphPinComponent: GraphComponent {
    var pin: Pin
    var ownerID: UUID?
    var ownerPosition: CGPoint
    var ownerRotation: CGFloat
    var layerId: UUID?
    var isSelectable: Bool
}

extension GraphPinComponent {
    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
            .rotated(by: ownerRotation)
    }

    var worldTransform: CGAffineTransform {
        CGAffineTransform(translationX: pin.position.x, y: pin.position.y)
            .concatenating(ownerTransform)
    }
}
