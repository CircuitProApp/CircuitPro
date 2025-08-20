//
//  ListConfiguration.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI

struct ListConfiguration {
    var listPadding: EdgeInsets = .init()
    
    var listRowSpacing: CGFloat = 0
    var listRowHeight: CGFloat?
    var listRowPadding: EdgeInsets = .init()

    var headerStyle: ListHeaderStyle = .regular
    var headerPadding: EdgeInsets = .init()
    var activeHeaderBackgroundStyle: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial)
    


    var selectionCornerRadius: CGFloat = 0
    var selectionBackgroundColor: Color = .blue
    var selectionForegroundColor: Color = .primary

    init() {}
}

enum ListHeaderStyle {
    case regular
    case hud
}

private struct ListConfigurationKey: EnvironmentKey {
    static var defaultValue: ListConfiguration { .init() }
}

extension EnvironmentValues {
    var listConfiguration: ListConfiguration {
        get { self[ListConfigurationKey.self] }
        set { self[ListConfigurationKey.self] = newValue }
    }
}

extension View {
    /// Merges the given edits into the current ListConfiguration and writes it into the environment.
    func listConfiguration(_ configure: @escaping (inout ListConfiguration) -> Void) -> some View {
        modifier(ListConfigurationWriter(configure: configure))
    }
}

private struct ListConfigurationWriter: ViewModifier {
    @Environment(\.listConfiguration) private var base
    let configure: (inout ListConfiguration) -> Void

    func body(content: Content) -> some View {
        var next = base
        configure(&next)
        return content.environment(\.listConfiguration, next)
    }
}
