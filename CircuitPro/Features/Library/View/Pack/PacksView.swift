//
//  PacksView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct PacksView: View {
    
    @BindableEnvironment(LibraryManager.self)
    private var libraryManager
    
    @PackManager private var packManager
    
    private static let lastCheckedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    private var filteredInstalledPacks: [InstalledPack] {
        if libraryManager.searchText.isEmpty {
            return packManager.installedPacks
        } else {
            return packManager.installedPacks.filter { $0.metadata.title.localizedCaseInsensitiveContains(libraryManager.searchText) }
        }
    }
    
    private var filteredAvailablePacks: [RemotePack] {
        if libraryManager.searchText.isEmpty {
            return libraryManager.remotePackProvider.allRemotePacks
        } else {
            return libraryManager.remotePackProvider.allRemotePacks.filter { $0.title.localizedCaseInsensitiveContains(libraryManager.searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GroupedList(selection: $libraryManager.selectedPack) {
                installedPacksSection()
                availablePacksSection()
            }
            .listConfiguration { configuration in
                configuration.headerStyle = .hud
                configuration.headerPadding = .init(top: 2, leading: 8, bottom: 2, trailing: 8)
                configuration.listPadding = .all(8)
                configuration.listRowPadding = .all(4)
                configuration.selectionCornerRadius = 8
            }
            
            Divider()
            actionFooter()
        }
        .task {
            await libraryManager.remotePackProvider.refresh(localPacks: packManager.installedPacks)
        }
        .onChange(of: packManager.installedPacks) { _, newLocalPacks in
            libraryManager.remotePackProvider.resync(with: newLocalPacks)
        }
    }
    
    @ViewBuilder
    private func actionFooter() -> some View {
        HStack {
            if libraryManager.remotePackProvider.isRefreshing {
                Text("Checking for updates...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lastRefreshed = libraryManager.remotePackProvider.lastRefreshed {
                Text("Last checked: \(Self.lastCheckedDateFormatter.string(from: lastRefreshed))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if libraryManager.remotePackProvider.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task {
                        await libraryManager.remotePackProvider.refresh(localPacks: packManager.installedPacks)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(libraryManager.remotePackProvider.isRefreshing)
                .buttonStyle(.plain)
                .help("Refresh Pack lists")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func emptyView(_ title: String) -> some View {
        HStack {
            Spacer()
            Text(title)
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
        }
        .frame(height: 70)
    }
    
    @ViewBuilder
    private func installedPacksSection() -> some View {
        Section {
            if packManager.installedPacks.isEmpty {
                emptyView("No packs installed")
            } else {
                ForEach(filteredInstalledPacks) { pack in
                    let packEnum = AnyPack.installed(pack)
                    let updateInfo = libraryManager.remotePackProvider.availableUpdates[pack.id]
                    
                    PackListRowView(
                        pack: packEnum,
                        isUpdateAvailable: updateInfo != nil,
                        onUpdate: {
                            if let update = updateInfo {
                                Task {
                                    await libraryManager.remotePackProvider.updateExistingPack(pack: update, packManager: packManager)
                                }
                            }
                        }
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
    }
    
    @ViewBuilder
    private func availablePacksSection() -> some View {
        Section {
            switch libraryManager.remotePackProvider.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
            case .failed(let error):
                ContentUnavailableView("Load Failed", systemImage: "wifi.exclamationmark", description: Text(error.localizedDescription))
                
            case .loaded(let availablePacks):
                if availablePacks.isEmpty {
                    emptyView("All available packs are installed")
                } else {
                    ForEach(filteredAvailablePacks) { pack in
                        let packEnum = AnyPack.remote(pack)
                        
                        PackListRowView(
                            pack: packEnum,
                            isUpdateAvailable: false,
                            onDownload: {
                                Task {
                                    await libraryManager.remotePackProvider.installNewPack(pack: pack, packManager: packManager)
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
}
