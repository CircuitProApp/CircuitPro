//
//  LibraryManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

import Foundation

struct RemotePack: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let version: Int
    let description: String
    let downloadURL: URL
}

@MainActor
@Observable
class LibraryManager {
    
    // MARK - State Management
    var searchText: String = ""
    /// Represents the different states of fetching the remote pack list.
    enum LoadState {
        case idle
        case loading
        case loaded([RemotePack]) // This will now hold only the *available for download* packs
        case failed(Error)
    }
    
    /// The current state of the remote library, driving the UI.
    var loadState: LoadState = .idle
    
    /// A dictionary mapping the ID of an installed pack to its available update info.
    var availableUpdates: [UUID: RemotePack] = [:]
    
    /// The ID of a pack that is currently being downloaded/installed.
    var activeDownloadID: UUID?
    
    /// **FIXED:** A private property to hold the complete, unfiltered list of packs from the server.
    private var allRemotePacks: [RemotePack] = []
    
    // MARK - Core Logic
    
    /// Fetches the list of available packs from the remote JSON file.
    func fetchAvailablePacks(localPacks: [InstalledPack]) async {
        guard activeDownloadID == nil else { return }
        if case .loading = loadState { return }
        
        self.loadState = .loading
        
        let url = URL(string: "https://raw.githubusercontent.com/CircuitProApp/CircuitProPacks/main/available_packs.json")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let remotePacks = try JSONDecoder().decode([RemotePack].self, from: data)
            // Store the complete list
            self.allRemotePacks = remotePacks
            // Now process it
            processPacks(local: localPacks)
            
        } catch {
            self.loadState = .failed(error)
        }
    }
    
    /// **REFACTORED:** Compares remote and local packs to categorize them.
    /// It now uses the `allRemotePacks` property as the source of truth.
    private func processPacks(local: [InstalledPack]) {
        let localPacksDict = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        
        var newAvailablePacks: [RemotePack] = []
        var newAvailableUpdates: [UUID: RemotePack] = [:]
        
        // Iterate over the complete list of remote packs
        for remotePack in allRemotePacks {
            if let localPack = localPacksDict[remotePack.id] {
                // Pack is installed. Check for updates.
                if remotePack.version > localPack.metadata.version {
                    newAvailableUpdates[localPack.id] = remotePack
                }
            } else {
                // Pack is not installed. Add to available list.
                newAvailablePacks.append(remotePack)
            }
        }
        
        self.availableUpdates = newAvailableUpdates
        self.loadState = .loaded(newAvailablePacks)
    }
    
    // MARK - User Intentions
    
    /// **REFACTORED:** Re-evaluates the library state. Now it's simpler and more reliable.
    func resync(with localPacks: [InstalledPack]) {
        // Re-run the comparison logic with the updated local packs against the full remote list.
        processPacks(local: localPacks)
    }
    
    /// Downloads and installs a given pack.
    func downloadAndInstall(pack: RemotePack, packManager: SwiftDataPackManager) async {
        activeDownloadID = pack.id
        
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("Failed to get caches directory.")
            activeDownloadID = nil
            return
        }
        
        let zipFileURL = cachesDirectory.appendingPathComponent(pack.id.uuidString + ".zip")
        let unzippedPackURL = cachesDirectory.appendingPathComponent(pack.id.uuidString + ".pack")
        
        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: pack.downloadURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            if FileManager.default.fileExists(atPath: zipFileURL.path) {
                try FileManager.default.removeItem(at: zipFileURL)
            }
            if FileManager.default.fileExists(atPath: unzippedPackURL.path) {
                try FileManager.default.removeItem(at: unzippedPackURL)
            }
            
            try FileManager.default.moveItem(at: temporaryURL, to: zipFileURL)
            try FileManager.default.unzipItem(at: zipFileURL, to: unzippedPackURL)
            
            packManager.installPack(from: unzippedPackURL)
            
            try FileManager.default.removeItem(at: zipFileURL)
            try FileManager.default.removeItem(at: unzippedPackURL)
            
            // **FIXED:** After successful installation, re-run the processing logic.
            processPacks(local: packManager.installedPacks)
            
        } catch {
            print("Failed to download or install pack: \(error.localizedDescription)")
        }
        
        activeDownloadID = nil
    }
    
    // ... (logDirectoryContents remains the same)
    fileprivate func logDirectoryContents(of url: URL, description: String) {
        print("\n--- 🪵 DEBUG: \(description) at \(url.path) 🪵 ---")
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            print("    [ERROR] Failed to enumerate directory.")
            print("--- END LOG ---\n")
            return
        }
        
        var foundFiles = false
        for case let fileURL as URL in enumerator {
            do {
                let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                if fileAttributes.isRegularFile! {
                    let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
                    print("    -> \(relativePath)")
                    foundFiles = true
                }
            } catch {
                print("    [ERROR] Could not get attributes for \(fileURL.path): \(error)")
            }
        }
        
        if !foundFiles {
            print("    [INFO] No files found in directory.")
        }
        print("--- END LOG ---\n")
    }
}
