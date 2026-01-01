//
//  HitTestPriorityProviding.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// Provides a priority hint for hit testing (higher wins).
protocol HitTestPriorityProviding {
    var hitTestPriority: Int { get }
}

extension HitTestPriorityProviding {
    var hitTestPriority: Int { 0 }
}
