//
//  CanvasStatusBarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/15/25.
//

import SwiftUI

struct CanvasStatusBarView: View {
    
    @Binding var isCollapsed: Bool
    
    var configuration: Configuration = .default
    
    enum Configuration {
        case `default`
        case fixedGrid
    }
    
    var body: some View {
        StatusBarView {
            CrosshairsStyleControlView()
            if configuration == .default {
                Divider()
                    .statusBardividerStyle()
                SnappingControlView()
            }
        } center: {
            MouseLocationView()
        } trailing: {
            if configuration == .default {
                GridSpacingControlView()
                Divider()
                    .statusBardividerStyle()
            }
            ZoomControlView()
            Divider()
                .statusBardividerStyle()
            CollapsePaneButton(isCollapsed: $isCollapsed)
        }
        
    }
}
