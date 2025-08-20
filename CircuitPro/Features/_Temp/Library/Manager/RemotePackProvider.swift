//
//  RemotePackProvider.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI
import SwiftDataPacks

@MainActor
@Observable
class RemotePackProvider {
    
    // State related to remote packs now lives here
    enum LoadState {
        case idle
        case loading
        case loaded([RemotePack])
        case failed(Error)
    }
    
    var loadState: LoadState = .idle
    var isRefreshing: Bool = false
    var availableUpdates: [UUID: RemotePack] = [:]
    var activeDownloadID: UUID?
    
    var allRemotePacks: [RemotePack] = []

    // MARK: - Core Logic

    func refresh(localPacks: [InstalledPack]) async {
        guard !isRefreshing else { return }
        
        self.isRefreshing = true
        if case .idle = loadState {
            self.loadState = .loading
        }
        
        defer { self.isRefreshing = false }
        
        let url = URL(string: "https://raw.githubusercontent.com/CircuitProApp/CircuitProPacks/main/available_packs.json")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let remotePacks = try JSONDecoder().decode([RemotePack].self, from: data)
            self.allRemotePacks = remotePacks
            processPacks(local: localPacks)
        } catch {
            self.loadState = .failed(error)
        }
    }
    
    private func processPacks(local: [InstalledPack]) {
        let localPacksDict = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        var newAvailablePacks: [RemotePack] = []
        var newAvailableUpdates: [UUID: RemotePack] = [:]
        
        for remotePack in allRemotePacks {
            if let localPack = localPacksDict[remotePack.id] {
                if remotePack.version > localPack.metadata.version {
                    newAvailableUpdates[localPack.id] = remotePack
                }
            } else {
                newAvailablePacks.append(remotePack)
            }
        }
        
        self.availableUpdates = newAvailableUpdates
        self.loadState = .loaded(newAvailablePacks)
    }
    
    func resync(with localPacks: [InstalledPack]) {
        processPacks(local: localPacks)
    }
    
    // MARK: - Install/Update APIs
    
    func installNewPack(pack: RemotePack, packManager: SwiftDataPackManager) async {
        // ... this implementation remains identical ...
        var tempURL: URL?
        do {
            tempURL = try await _downloadAndUnpack(remotePack: pack)
            
            defer {
                if let url = tempURL { try? FileManager.default.removeItem(at: url) }
                activeDownloadID = nil
            }
            packManager.installPack(from: tempURL!)
        } catch {
            print("Failed to install new pack: \(error.localizedDescription)")
            if let url = tempURL { try? FileManager.default.removeItem(at: url) }
            activeDownloadID = nil
        }
    }

    func updateExistingPack(pack: RemotePack, packManager: SwiftDataPackManager) async {
        // ... this implementation remains identical ...
        var tempURL: URL?
        do {
            tempURL = try await _downloadAndUnpack(remotePack: pack)
            
            defer {
                if let url = tempURL { try? FileManager.default.removeItem(at: url) }
                activeDownloadID = nil
            }
            packManager.updatePack(from: tempURL!)
        } catch {
            print("Failed to update existing pack: \(error.localizedDescription)")
            if let url = tempURL { try? FileManager.default.removeItem(at: url) }
            activeDownloadID = nil
        }
    }

    private func _downloadAndUnpack(remotePack pack: RemotePack) async throws -> URL {
        // ... this implementation remains identical ...
        activeDownloadID = pack.id
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            activeDownloadID = nil
            throw PackManagerError.installationFailed(reason: "Could not find caches directory.")
        }
        let zipFileURL = cachesDirectory.appendingPathComponent(pack.id.uuidString + ".zip")
        let unzippedPackURL = cachesDirectory.appendingPathComponent(pack.id.uuidString + ".unpacked")
        try? FileManager.default.removeItem(at: zipFileURL)
        try? FileManager.default.removeItem(at: unzippedPackURL)
        let (temporaryURL, response) = try await URLSession.shared.download(from: pack.downloadURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        try FileManager.default.moveItem(at: temporaryURL, to: zipFileURL)
        try FileManager.default.unzipItem(at: zipFileURL, to: unzippedPackURL)
        try? FileManager.default.removeItem(at: zipFileURL)
        return unzippedPackURL
    }
}
