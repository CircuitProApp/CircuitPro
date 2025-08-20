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
    
    @State private var selectedPack: AnyHashable?
    
    var body: some View {
        
        @Bindable var libraryManager = libraryManager
        GroupedList(selection: $selectedPack) {
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
                            .listID(pack)
                            .contextMenu {
                                Button {
                                    packManager.removePack(id: pack.id)
                                } label: {
                                    Text("Delete Pack")
                                }
                            }
                       
                        }
                    }
                } header: {
                    Text("Installed")
                        .font(.caption)
                        .fontWeight(.light)
                        .foregroundStyle(.secondary)
                }
      
                Section {
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
                                .listID(pack)
                              
                            }
                        }
                    }
                } header: {
                    Text("Available to Download")
                        .listHeaderStyle()
                    
                }
        }
        .listConfiguration { configuration in
            configuration.headerStyle = .hud
            configuration.headerPadding = .init(top: 2, leading: 8, bottom: 2, trailing: 8)
            configuration.listPadding = .all(8)
            configuration.listRowPadding = .all(4)
            configuration.selectionCornerRadius = 8
  
        }
        .task {
            await libraryManager.fetchAvailablePacks(localPacks: packManager.installedPacks)
        }
        .onChange(of: packManager.installedPacks) { _, newLocalPacks in
            libraryManager.resync(with: newLocalPacks)
        }
    }
}
