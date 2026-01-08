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
        Grid {
            GridRow {
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
                .frame(maxWidth: .infinity, alignment: .leading)

                MouseLocationView()
                    .padding(10)
                    .glassEffect(in: .capsule)

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
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
