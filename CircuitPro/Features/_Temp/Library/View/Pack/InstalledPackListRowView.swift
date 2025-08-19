//
//  InstalledPackListRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//


import SwiftUI
import SwiftDataPacks

struct InstalledPackListRowView: View {
    let pack: InstalledPack
    
    /// Set this to true to show the update button.
    var isUpdateAvailable: Bool
    
    /// A binding to the ID of the pack currently being downloaded/updated.
    @Binding var activeDownloadID: UUID?
    
    /// The action to perform when the update button is tapped.
    var onUpdate: () -> Void
    
    /// Computed property to check if THIS pack is the one being updated.
    private var isUpdating: Bool {
        activeDownloadID == pack.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(.brown)
                .frame(width: 30)

            Text(pack.metadata.title)
                .font(.headline)
            
            Spacer()
            
            // The view now has three states: Updating, Update Available, or Up-to-date
            if isUpdating {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 90, height: 35) // Reserve space to prevent layout shifts
            } else if isUpdateAvailable {
                Button("Update", action: onUpdate)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(width: 90, height: 35)
            } else {
                Text("v\(pack.metadata.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
