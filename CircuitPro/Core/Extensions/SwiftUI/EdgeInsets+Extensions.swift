//
//  EdgeInsets+Extensions.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI

extension EdgeInsets {
    static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
    static func horizontal(_ value: CGFloat, vertical: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(top: vertical, leading: value, bottom: vertical, trailing: value)
    }
    static func vertical(_ value: CGFloat, horizontal: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(top: value, leading: horizontal, bottom: value, trailing: horizontal)
    }
}
