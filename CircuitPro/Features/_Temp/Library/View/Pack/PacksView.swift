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
    
    @State private var selectedPack: AnyPack?
    
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
                        let packEnum = AnyPack.installed(pack)
                        let updateInfo = libraryManager.availableUpdates[pack.id]
                        
                        PackListRowView(
                            pack: packEnum,
                            selectedPack: $selectedPack,
                            activeDownloadID: $libraryManager.activeDownloadID,
                            isUpdateAvailable: updateInfo != nil,
                            onUpdate: {
                                if let update = updateInfo {
                                    Task {
                                        await libraryManager.updateExistingPack(pack: update, packManager: packManager)
                                    }
                                }
                            },
                            onDownload: {}
                        )
                        .listID(packEnum)
                        .contextMenu {
                            Button(role: .destructive) {
                                packManager.removePack(id: pack.id)
                            } label: {
                                Text("Delete Pack")
                            }
                        }
                    }
                }
            } header: {
                Text("Installed")
                    .listHeaderStyle()
            }
            
            Section {
                switch libraryManager.loadState {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                case .failed(let error):
                    ContentUnavailableView("Load Failed", systemImage: "wifi.exclamationmark", description: Text(error.localizedDescription))
                    
                case .loaded(let availablePacks):
                    if availablePacks.isEmpty {
                        HStack {
                            Spacer()
                            Text("All available packs are installed")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                            Spacer()
                        }
                        .frame(height: 70)
                    } else {
                        ForEach(availablePacks) { pack in
                            let packEnum = AnyPack.remote(pack)
                            
                            PackListRowView(
                                pack: packEnum,
                                selectedPack: $selectedPack,
                                activeDownloadID: $libraryManager.activeDownloadID,
                                isUpdateAvailable: false,
                                onUpdate: {},
                                onDownload: {
                                    Task {
                                        await libraryManager.installNewPack(pack: pack, packManager: packManager)
                                    }
                                }
                            )
                            .listID(packEnum)
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
