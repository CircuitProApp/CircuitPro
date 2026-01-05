//
//  If.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 01.06.25.
//

import SwiftUI

extension View {
    /// Applies `transform` when `condition` is true, otherwise applies `elseTransform`.
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: @autoclosure () -> Bool,
        transform: (Self) -> TrueContent,
        `else` elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition() {
            transform(self)
        } else {
            elseTransform(self)
        }
    }

    /// Keeps the original single-branch version for backwards compatibility.
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: @autoclosure () -> Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}
