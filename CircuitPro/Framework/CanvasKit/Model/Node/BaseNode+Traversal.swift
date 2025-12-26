//
//  BaseNode+Traversal.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

extension BaseNode {
    func flattened() -> [BaseNode] {
        var nodes = [self]
        for child in children {
            nodes.append(contentsOf: child.flattened())
        }
        return nodes
    }
}

extension Array where Element == BaseNode {
    func flattened() -> [BaseNode] {
        flatMap { $0.flattened() }
    }
}
