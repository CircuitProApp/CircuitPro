//
//  Unit.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

struct Unit: CustomStringConvertible, Codable, Equatable, Hashable {
    var prefix: SIPrefix?
    var base: BaseUnit?

    var symbol: String {
        let prefixSymbol = prefix?.symbol ?? ""
        let baseSymbol = base?.symbol ?? ""
        return "\(prefixSymbol)\(baseSymbol)"
    }

    var name: String {
        guard let base = base else { return prefix?.name ?? "" }
        let prefixString = prefix?.name ?? ""
        return [prefixString, base.name].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var description: String { symbol }

    init(prefix: SIPrefix? = nil, base: BaseUnit? = nil) {
        if let base = base, !base.allowsPrefix, prefix != nil {
            fatalError("Invalid prefix for base unit.")
        }
        self.prefix = prefix
        self.base = base
    }
}
