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
            .modify { view in
                if #available(macOS 26.0, *) {
                    view.glassEffect(in: .capsule)
                } else {
                    view
                        .background(.ultraThinMaterial)
                        .clipAndStroke(with: .rect(cornerRadius: 10), strokeColor: .gray.opacity(0.3))
                }
            }
            Spacer()
            MouseLocationView()
                .padding(10)
                .modify { view in
                    if #available(macOS 26.0, *) {
                        view.glassEffect(in: .capsule)
                    } else {
                        view
                            .background(.ultraThinMaterial)
                            .clipAndStroke(with: .rect(cornerRadius: 10), strokeColor: .gray.opacity(0.3))
                    }
                }
         
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
            .modify { view in
                if #available(macOS 26.0, *) {
                    view.glassEffect(in: .capsule)
                } else {
                    view
                        .background(.ultraThinMaterial)
                        .clipAndStroke(with: .rect(cornerRadius: 10), strokeColor: .gray.opacity(0.3))
                }
            }
        }

    }
}
