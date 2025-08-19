//
//  GroupedListConfiguration.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/19/25.
//

import SwiftUI

public struct GroupedListConfiguration {
    public var listRowSpacing: CGFloat
    public var listPadding: EdgeInsets
    public var listRowPadding: EdgeInsets
    public var listHeaderPadding: EdgeInsets
    public var listSelectionCornerRadius: CGFloat
    public var activeHeaderBackgroundColor: AnyShapeStyle
    public var isHudListStyle: Bool
    
    // Per-edge initializer
    public init(
        listRowSpacing: CGFloat = 0,
        listPadding: EdgeInsets = .init(),
        listRowPadding: EdgeInsets = .init(),
        listHeaderPadding: EdgeInsets = .init(),
        listSelectionCornerRadius: CGFloat = 0,
        activeHeaderBackgroundColor: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial),
        isHudListStyle: Bool = false
    ) {
        self.listRowSpacing = listRowSpacing
        self.listPadding = listPadding
        self.listRowPadding = listRowPadding
        self.listHeaderPadding = listHeaderPadding
        self.listSelectionCornerRadius = listSelectionCornerRadius
        self.activeHeaderBackgroundColor = activeHeaderBackgroundColor
        self.isHudListStyle = isHudListStyle
    }
}

public extension EdgeInsets {
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
