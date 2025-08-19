//
//  GroupedListTagPreferenceKey.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/19/25.
//

import SwiftUI

struct GroupedListTagPreferenceKey: PreferenceKey {
    static var defaultValue: AnyHashable? = nil
    static func reduce(value: inout AnyHashable?, nextValue: () -> AnyHashable?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Attach a typed selection value for GroupedList to use.
    func groupedListTag<T: Hashable>(_ value: T) -> some View {
        preference(key: GroupedListTagPreferenceKey.self, value: AnyHashable(value))
    }
}
