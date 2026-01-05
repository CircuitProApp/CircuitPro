//
//  WireVertexPolicy.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct WireVertexPolicy: VertexPolicy {
    private let box: OwnershipLookupBox

    init(box: OwnershipLookupBox) { self.box = box }

    func isProtected(_ v: GraphVertex, state: GraphState) -> Bool {
        if case .pin = (box.lookup?(v.id) ?? .free) { return true }
        return false
    }
    func canCullIsolated(_ v: GraphVertex, state: GraphState) -> Bool {
        if case .free = (box.lookup?(v.id) ?? .free) { return true }
        return false
    }
    func preferSurvivor(_ candidates: [GraphVertex], state: GraphState) -> GraphVertex {
        candidates.first { isProtected($0, state: state) } ?? candidates[0]
    }
}
