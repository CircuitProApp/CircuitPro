//
//  CanvasStatusView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/15/25.
//

import SwiftUI

struct CanvasStatusView: View {

    var configuration: Configuration = .default

    enum Configuration {
        case `default`
        case fixedGrid
    }

    var body: some View {
        HStack {
            HStack {
                CrosshairsStyleControlView()
                if configuration == .default {
                    Divider()
                        .canvasStatusDividerStyle()
                    SnappingControlView()
                }
            }
            .padding(10)
            .glassEffect(in: .capsule)
            Spacer()
            MouseLocationView()
                .padding(10)
                .glassEffect(in: .capsule)
         
            Spacer()
            HStack {
                if configuration == .default {
                    GridSpacingControlView()
                    Divider()
                        .canvasStatusDividerStyle()
                }
                ZoomControlView()
            }
            .padding(10)
            .glassEffect(in: .capsule)
        }

    }
}
