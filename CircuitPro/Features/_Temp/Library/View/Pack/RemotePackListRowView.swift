//
//  RemotePackListRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//


import SwiftUI

struct RemotePackListRowView: View {
    let pack: RemotePack // Your model for a pack on the server
    
    /// A binding to the ID of the pack currently being downloaded.
    @Binding var downloadingPackID: UUID?
    
    /// The action to perform when the download button is tapped.
    var onDownload: () -> Void
    
    /// Computed property to check if THIS pack is the one downloading.
    private var isDownloading: Bool {
        downloadingPackID == pack.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.title2)
                .foregroundStyle(.brown)
                .symbolVariant(.fill)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(pack.title)
                    .font(.headline)
                Text("Version \(pack.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isDownloading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 90) // Reserve space to prevent layout shift
            } else {
                Button {
                    onDownload()
                } label: {
                    Image(systemName: "arrow.down")
                        .symbolVariant(.circle)
                        .foregroundStyle(.blue)
                        .frame(width: 90)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
