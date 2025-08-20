//
//  PackListRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct PackListRowView: View {
    
    @Environment(LibraryManager.self)
    private var libraryManager
    // The pack to display, which can be either installed or remote.
    let pack: AnyPack
    
    // State flags and action closures provided by the parent view.
    var isUpdateAvailable: Bool
    var onUpdate: () -> Void = { }
    var onDownload: () -> Void = { }
    
    // Computed properties to determine the row's current state.
    private var isSelected: Bool {
        libraryManager.selectedPack == pack
    }
    
    private var isProcessing: Bool {
        libraryManager.remotePackProvider.activeDownloadID == pack.id
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .imageScale(.large)
                .symbolVariant(.fill)
                .foregroundStyle(isSelected ? .white : .brown)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 0) {
                Text(pack.title)
                Text("Version \(pack.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
            }
            Spacer()
            trailingActionView
                .frame(width: 32, height: 32)
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
                    Button(action: onUpdate) {
                        Label("Update", systemImage: "arrow.down")
                            .symbolVariant(.circle)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? .white : .blue)
                }
            case .remote:
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down")
                        .symbolVariant(.circle)
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? .white : .blue)
            }
        }
    }
}
