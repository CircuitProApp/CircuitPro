//
//  PackListRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct PackListRowView: View {
    // The pack to display, which can be either installed or remote.
    let pack: AnyPack
    
    // Bindings to track selection and download/update state across the list.
    @Binding var selectedPack: AnyPack?
    @Binding var activeDownloadID: UUID?
    
    // State flags and action closures provided by the parent view.
    var isUpdateAvailable: Bool
    var onUpdate: () -> Void
    var onDownload: () -> Void
    
    // Computed properties to determine the row's current state.
    private var isSelected: Bool {
        selectedPack == pack
    }
    
    private var isProcessing: Bool {
        activeDownloadID == pack.id
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // The main icon, which varies slightly for installed vs. remote packs.
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .imageScale(.large)
                .symbolVariant(.fill)
                .foregroundStyle(isSelected ? .white : .brown)
                .frame(width: 32)

            // The title and version information.
            VStack(alignment: .leading) {
                Text(pack.title)
                    .font(.headline)
                if case .remote = pack {
                    Text("Version \(pack.version)")
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            
            Spacer()
            
            // The trailing action view, which shows the most relevant state.
            trailingActionView
                .frame(width: 32) // Reserve space to prevent layout shifts.
        }
        .contentShape(.rect)
        .foregroundStyle(isSelected ? .white : .primary)
    }
    
    /// Provides the correct view for the trailing edge of the row based on the pack's state.
    @ViewBuilder
    private var trailingActionView: some View {
        if isProcessing {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
        } else {
            switch pack {
            case .installed:
                if isUpdateAvailable {
                    Button("Update", action: onUpdate)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                } else {
                    Text("v\(pack.version)")
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .animation(nil, value: UUID()) // Prevent animation during state changes
                }
            case .remote:
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down")
                        .symbolVariant(.circle)
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? .white : .blue)
            }
        }
    }
}
