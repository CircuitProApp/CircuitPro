//
//  Net+Merge.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/6/25.
//

import Foundation
import CoreGraphics

extension Net {
    mutating func mergeColinearEdges() {
        // 1 Build adjacency
        func rebuild() -> [UUID:[Edge]] {
            var adj:[UUID:[Edge]] = [:]
            for e in edges {
                adj[e.a, default:[]].append(e)
                adj[e.b, default:[]].append(e)
            }
            return adj
        }

        var adjacency = rebuild()
        var changed = true

        while changed {
            changed = false
            for (nid, connected) in adjacency {
                guard connected.count == 2,
                      let n = nodeByID[nid],
                      n.kind != .junction else { continue }

                let e1 = connected[0]
                let e2 = connected[1]

                let o1 = (e1.a == nid ? e1.b : e1.a)
                let o2 = (e2.a == nid ? e2.b : e2.a)

                guard o1 != o2,
                      let p0 = nodeByID[o1]?.point,
                      let p1 = n.point as CGPoint?,
                      let p2 = nodeByID[o2]?.point else { continue }

                let h = (p0.y == p1.y) && (p1.y == p2.y)
                let v = (p0.x == p1.x) && (p1.x == p2.x)
                guard h || v else { continue }

                edges.removeAll { $0.id == e1.id || $0.id == e2.id }
                nodeByID.removeValue(forKey: nid)
                let newEdge = Edge(id: UUID(), a: o1, b: o2)
                edges.append(newEdge)

                adjacency = rebuild()
                changed = true
                break
            }
        }
    }

    static func findAndMergeIntentionalIntersections(
        between a: inout Net, and b: inout Net) -> Bool
    {
        var hits:[(UUID,UUID,CGPoint)] = []

        for ea in a.edges {
            guard let a0 = a.nodeByID[ea.a], let a1 = a.nodeByID[ea.b] else { continue }
            let sa = LineSegment(start:a0.point,end:a1.point)

            for eb in b.edges {
                guard let b0 = b.nodeByID[eb.a], let b1 = b.nodeByID[eb.b] else { continue }
                let sb = LineSegment(start:b0.point,end:b1.point)

                if let p = sa.intersectionPoint(with: sb) {
                    if a.hasNode(at:p) || b.hasNode(at:p) {
                        hits.append((ea.id,eb.id,p))
                    }
                }
            }
        }

        guard !hits.isEmpty else { return false }

        for h in hits {
            let newJ = a.splitEdge(withID: h.0, at: h.2)
            if let j = newJ,
               let idx = b.edges.firstIndex(where: { $0.id == h.1 }),
               let b0 = b.nodeByID[b.edges[idx].a],
               let b1 = b.nodeByID[b.edges[idx].b] {
                let e1 = Edge(id: UUID(), a: b0.id, b: j)
                let e2 = Edge(id: UUID(), a: j,     b: b1.id)
                b.edges.remove(at: idx)
                b.edges.append(contentsOf:[e1,e2])
            }
        }
        return true
    }

    static func findAndMergeIntersections(
        between a: inout Net, and b: inout Net) -> Bool
    {
        findAndMergeIntentionalIntersections(between:&a,and:&b)
    }

    private func hasNode(at p:CGPoint,tolerance:CGFloat=0.5)->Bool {
        nodeByID.values.contains {
            abs($0.point.x - p.x) < tolerance &&
            abs($0.point.y - p.y) < tolerance
        }
    }
}
