//
//  Net+Split.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import Foundation
import CoreGraphics

extension Net {
    @discardableResult
    mutating func splitEdge(withID eid:UUID,at p:CGPoint)->UUID? {
        // 1 Find edge
        guard let idx = edges.firstIndex(where:{ $0.id == eid }),
              let nA = nodeByID[edges[idx].a],
              let nB = nodeByID[edges[idx].b] else { return nil }

        // 2 New node
        let j = Node(id:UUID(),point:p,kind:.junction)
        nodeByID[j.id] = j

        // 3 Two new edges
        let e1 = Edge(id:UUID(),a:nA.id,b:j.id)
        let e2 = Edge(id:UUID(),a:j.id,b:nB.id)

        // 4 Replace
        edges.remove(at:idx)
        edges.append(contentsOf:[e1,e2])
        return j.id
    }
}
