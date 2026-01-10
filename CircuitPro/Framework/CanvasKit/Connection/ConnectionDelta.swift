//
//  ConnectionDelta.swift
//  CircuitPro
//
//  Created by Codex on 1/4/26.
//

import Foundation

struct ConnectionDelta {
    var removedPointIDs: Set<UUID> = []
    var updatedPoints: [any CanvasItem & ConnectionPoint] = []
    var addedPoints: [any CanvasItem & ConnectionPoint] = []
    var removedLinkIDs: Set<UUID> = []
    var updatedLinks: [any CanvasItem & ConnectionLink] = []
    var addedLinks: [any CanvasItem & ConnectionLink] = []

    var isEmpty: Bool {
        removedPointIDs.isEmpty
            && updatedPoints.isEmpty
            && addedPoints.isEmpty
            && removedLinkIDs.isEmpty
            && updatedLinks.isEmpty
            && addedLinks.isEmpty
    }
}
