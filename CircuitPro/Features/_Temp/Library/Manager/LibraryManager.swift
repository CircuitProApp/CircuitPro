//
//  LibraryManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

@MainActor
@Observable
class LibraryManager {
    
    // MARK - State Management
    var searchText: String = ""
    enum LoadState {
        case idle
        case loading
        case loaded([RemotePack])
        case failed(Error)
    }
    
    var loadState: LoadState = .idle
    var availableUpdates: [UUID: RemotePack] = [:]
    var activeDownloadID: UUID?
    private var allRemotePacks: [RemotePack] = []
    
    // MARK: - Core Logic
    
    func fetchAvailablePacks(localPacks: [InstalledPack]) async {
        if case .loading = loadState { return }
        
        self.loadState = .loading
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
    
    // MARK: - Public Install/Update APIs
    
    func installNewPack(pack: RemotePack, packManager: SwiftDataPackManager) async {
        var tempURL: URL?
        do {
            tempURL = try await _downloadAndUnpack(remotePack: pack)
            
            // The defer block ensures cleanup happens after we are done with tempURL
            defer {
                if let url = tempURL {
                    try? FileManager.default.removeItem(at: url)
                }
                // Reset the active ID *after* all operations are complete
                activeDownloadID = nil
            }
            
            packManager.installPack(from: tempURL!)
        } catch {
            print("Failed to install new pack: \(error.localizedDescription)")
            // If an error occurred, cleanup the temp file if it exists and reset state
            if let url = tempURL { try? FileManager.default.removeItem(at: url) }
            activeDownloadID = nil
        }
    }

    func updateExistingPack(pack: RemotePack, packManager: SwiftDataPackManager) async {
        var tempURL: URL?
        do {
            tempURL = try await _downloadAndUnpack(remotePack: pack)
            
            defer {
                if let url = tempURL {
                    try? FileManager.default.removeItem(at: url)
                }
                activeDownloadID = nil
            }
            
            packManager.updatePack(from: tempURL!)
        } catch {
            print("Failed to update existing pack: \(error.localizedDescription)")
            if let url = tempURL { try? FileManager.default.removeItem(at: url) }
            activeDownloadID = nil
        }
    }

    // MARK: - Private Helper
    
    /// **FIXED:** This function now ONLY downloads and unpacks. It does NOT do cleanup.
    private func _downloadAndUnpack(remotePack pack: RemotePack) async throws -> URL {
        activeDownloadID = pack.id
        
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            activeDownloadID = nil // Still reset state on early failure
            throw PackManagerError.installationFailed(reason: "Could not find caches directory.")
        }
        
        let zipFileURL = cachesDirectory.appendingPathComponent(pack.id.uuidString + ".zip")
        let unzippedPackURL = cachesDirectory.appendingPathComponent(pack.id.uuidString + ".unpacked")
        
        // Clean up any old remnants *before* starting a new operation.
        try? FileManager.default.removeItem(at: zipFileURL)
        try? FileManager.default.removeItem(at: unzippedPackURL)
        
        let (temporaryURL, response) = try await URLSession.shared.download(from: pack.downloadURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        try FileManager.default.moveItem(at: temporaryURL, to: zipFileURL)
        try FileManager.default.unzipItem(at: zipFileURL, to: unzippedPackURL)
        
        // No longer need the zip file
        try? FileManager.default.removeItem(at: zipFileURL)
        
        return unzippedPackURL
    }
}
