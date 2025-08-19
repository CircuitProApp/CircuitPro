//
//  PacksView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct PacksView: View {
    
    @Environment(LibraryManager.self) private var libraryManager
    @PackManager private var packManager
    
    var body: some View {
        
        @Bindable var libraryManager = libraryManager
        ScrollView {
            LazyVStack {
                // --- INSTALLED PACKS SECTION (ALWAYS VISIBLE) ---
                Section {
                    if packManager.installedPacks.isEmpty {
                        HStack {
                            Spacer()
                            Text("No packs installed")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                            Spacer()
                        }
                        .frame(height: 70)
                    } else {
                        ForEach(packManager.installedPacks) { pack in
                            let updateInfo = libraryManager.availableUpdates[pack.id]
                            
                            InstalledPackListRowView(
                                pack: pack,
                                isUpdateAvailable: updateInfo != nil,
                                activeDownloadID: $libraryManager.activeDownloadID,
                                onUpdate: {
                                    if let update = updateInfo {
                                        Task {
                                            await libraryManager.downloadAndInstall(pack: update, packManager: packManager)
                                        }
                                    }
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Remove", role: .destructive) {
                                    // Just perform the action. The .onChange modifier will handle the sync.
                                    packManager.removePack(id: pack.id)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Installed")
                }
      
                
                // --- AVAILABLE TO DOWNLOAD SECTION (STATE-DRIVEN) ---
                Section("Available to Download") {
                    switch libraryManager.loadState {
                    case .idle, .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                    case .failed(let error):
                        ContentUnavailableView("Load Failed", systemImage: "wifi.exclamationmark", description: Text(error.localizedDescription))
                        
                    case .loaded(let availablePacks):
                        if availablePacks.isEmpty {
                            Text("All available packs are installed.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(availablePacks) { pack in
                                RemotePackListRowView(
                                    pack: pack,
                                    downloadingPackID: $libraryManager.activeDownloadID,
                                    onDownload: {
                                        Task {
                                            await libraryManager.downloadAndInstall(pack: pack, packManager: packManager)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .task {
            await libraryManager.fetchAvailablePacks(localPacks: packManager.installedPacks)
        }
        // **FIXED:** Use onChange to react to changes in the installed packs list.
        // This is the correct way to handle the state update after a pack is added or removed.
        .onChange(of: packManager.installedPacks) { _, newLocalPacks in
            libraryManager.resync(with: newLocalPacks)
        }
    }
}
